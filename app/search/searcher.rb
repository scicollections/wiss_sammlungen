require 'elasticsearch'
require Rails.root.join("config", "elasticsearch")

# Searcher
class Searcher
  attr_reader :query, :from, :size, :cat_filter, :facet_filter, :klass_filter, :role_filter,
              :results, :has_results, :has_more, :hits, :fallback, :fb_exception, :raw,
              :categories, :facets, :klasses, :roles, :MISSING_STRING

  alias_method :q, :query

  def initialize
    ## Input defaults
    @query  = ""    # Empty String means "match_all"
    @from   = 0
    @size   = 50    # (default) number of docs per page
    # Mode determines the search context
    # discover: Standard-search querying 'discover'-field, with category- and facet-filter
    # quicksearch: Internal search, with class- and scope-filter
    # surveycounter: Used to get numbers of collections with a given survey state e.g. "completed"
    @mode   = :discover
    @scope  = :public
    @sort_by_relevance = false
    @cat_filter   = ESConfig.categories.keys
    @facet_filter = {}
    @klass_filter = [] # empty Array = all
    @role_filter  = [] # empty Array = all
    # For better performance, only aggregate filterlists for given facets
    @aggregated_facets = []

    ## Output initial values
    @results      = nil
    @has_results  = false
    @has_more     = false
    @hits         = 0
    @fallback     = false
    @fb_exception = nil
    @raw          = nil

    @categories = {}
    ESConfig.categories.each { |k,v|
      @categories[k] = { name: v, count: 0 }
    }
    @facets = {}
    ESConfig.facets.each { |k,v|
      @facets[k] = { name: v, terms: {}, restrictions: ESConfig.restrictions[k] }
    }
    @klasses = {}
    @roles = {}
    
    @MISSING_STRING = "Nicht vergeben"
  end

  def configure args={}
    @query  = args[:query].to_s[0..200] if args[:query]
    @from   = args[:from].to_i          if args[:from]
    @size   = args[:size].to_i          if args[:size]
    @mode   = args[:mode]               if [:discover, :quicksearch, :surveycounter].include?(args[:mode])
    @scope  = args[:scope]              if User::ROLES.include?(args[:scope])
    @sort_by_relevance = args[:sort_by_relevance] if args[:sort_by_relevance]

    @cat_filter = ESConfig.categories.keys & [*args[:cat_filter]].map(&:to_sym) if args[:cat_filter]
    @cat_filter = ESConfig.categories.keys unless @cat_filter.any? # none == all
    self.facet_filter = args[:facet_filter] if args[:facet_filter]
    @klass_filter = [*args[:klass_filter]] if args[:klass_filter]
    @role_filter = User::ROLES & [*args[:role_filter]].map(&:to_sym) if args[:role_filter]
    @aggregated_facets = ESConfig.facets.keys & [*args[:aggregated_facets]].map(&:to_sym) if args[:aggregated_facets]
    
    # survey related
    @campaign_slug = args[:campaign_slug].to_s if args[:campaign_slug]
    @survey_status = args[:survey_status].to_s if args[:survey_status]
    @survey_status_exclude = args[:survey_status_exclude].collect{|status| status.to_s} if args[:survey_status_exclude]
  end

  def params
    {
      query: @query,
      #from: @from,
      #size: @size,
      mode: @mode,
      scope: @scope,
      cat_filter: @cat_filter,
      facet_filter: @facet_filter,
      klass_filter: @klass_filter,
      role_filter: @role_filter,
      hits: @hits
    }
  end

  def facet_filter= hsh
    @facet_filter = {}
    facets.keys.each do |k|
      if hsh[k].is_a?(Array)
        hsh[k] -= [""]
        hsh[k].compact!
        @facet_filter[k] = hsh[k] unless hsh[k].empty?
      end
    end if hsh.is_a?(Hash)
  end

  def add_facet key, val
    key = key.to_sym unless key.nil?
    if facets.keys.include? key and !val.nil? and val != ""
      @facet_filter[key] ||= []
      @facet_filter[key] += [val]
      @facet_filter[key].uniq!
    end
  end

  def remove_facet key, val
    key = key.to_sym unless key.nil?
    if @facet_filter[key].is_a?(Array)
      @facet_filter[key] -= [val]
      if @facet_filter[key].length == 0
        @facet_filter.delete(key)
      end
    end
  end

  def active_facets cat=@cat_filter
    @facet_filter.keys.select do |k|
      ESConfig.restrictions[k] == nil || (ESConfig.restrictions[k] & [*cat]).any?
    end
  end

  def find id
    esc = Elasticsearch::Client.new host: ESConfig.connection["host"], port: ESConfig.connection["port"]

    begin
      doc = esc.get(index: "#{ESConfig.connection['prefix']}_#{ESConfig.connection['searchindex']}", type: "individual", id: id)

      doc2hsh(doc)
    rescue
      nil
    end
  end

  def execute
    esc = Elasticsearch::Client.new host: ESConfig.connection["host"], port: ESConfig.connection["port"]

    #build searchquery
    dsl_query = build_dsl_query
    begin
      #query elasticsearch
      @raw = esc.search(index: "#{ESConfig.connection['prefix']}_#{ESConfig.connection['searchindex']}", type: "individual", body:  dsl_query)
      
      extract_results

      extract_aggregations

      @fallback = false
    rescue => e
      if @mode != :surveycounter
        #execute fallback search if something with elasticsearch went wrong
        @fallback = true
        @fb_exception = e
        execute_fallback
      else
        @results = []
      end
    end
  end

  # return array of all selected foci to detect multiple applied of the same name
  def flat_foci_list
    active_facets.map do |k|
      @facet_filter[k]
    end.flatten
  end

  private


  ##### Before query #####

  def build_dsl_query
    # build query
    dsl_query =  { bool: {
        must: {},
        filter: {
          bool: {
            must: [{ terms: { scope: User::ROLES.take(User::ROLES.index(@scope) + 1) }} ],
            must_not: []
          } 
        }
      } 
    }  
    if @query == ""
      dsl_query[:bool][:must][:match_all] = {}
    else
      dsl_query[:bool][:must][:multi_match] = {
        query: @query,
        type: "cross_fields",
        fields: [
          "label^3",
          "inline_label^3",
          "headline^3",
          "subheadline^2",
          "description^2",
          "facet.*.search",
          "hidden",
          "same_as"
        ],
        operator: "and"
      }
    end
    
   

    pfilter = build_post_filter

    aggregations = build_aggregations
    
    sfilter = build_survey_filter
    dsl_query[:bool][:filter][:bool][:must].append(sfilter)

    sortmode = if @sort_by_relevance
      { sort: "_score" }
    elsif @mode == :discover
      { sort: "headline.sort" }
    else
      { sort: "inline_label.sort" }
    end
    
    { query: dsl_query,
      from: @from,
      size: @size,
    }.merge(pfilter).merge(aggregations).merge(sortmode)
  end

  def build_post_filter
    if @mode == :discover
      pfilter = {
        post_filter: {
          bool: {
            must: [
              { terms: { category: @cat_filter } }
            ]
          }
        }
      }

      if active_facets.any?
        pfilter[:post_filter][:bool][:must] += active_facets.map do |k|
          should_arr_query = {bool: {should: []}}
          if @facet_filter[k].include? @MISSING_STRING
            should_arr_query[:bool][:should] += [{bool: {must_not: {exists: {field: "facet.#{k}"}}}}]
          end
          should_arr_query[:bool][:should] += [{ terms: { "facet.#{k}" => @facet_filter[k] - [@MISSING_STRING] } }]
          should_arr_query
        end
      end

      pfilter
    elsif @mode == :quicksearch && (@klass_filter.any? || @role_filter.any?)
      must = []
      must << { terms: { klass: @klass_filter } } if @klass_filter.any?
      must << { terms: { scope: @role_filter } } if @role_filter.any?

      { post_filter: { bool: { must: must } } }
    else
      {}
    end
    
  end

  def build_aggregations
    aggs = { aggs: {} }

    ## Discover aggregations

    # category count
    @categories.keys.each do |k|
      aggs[:aggs]["cat_#{k}"] = {
        filter: {
          bool: {
            must: [{ term: { "category" => k } }]
          }
        }
      }
      
      aggs[:aggs]["cat_#{k}"][:filter][:bool][:must] += active_facets.map do |k|
        should_arr_query = {bool: {should: []}}
        if @facet_filter[k].include? @MISSING_STRING
          should_arr_query[:bool][:should] += [{bool: {must_not: {exists: {field: "facet.#{k}"}}}}]
        end
        should_arr_query[:bool][:should] += [{ terms: { "facet.#{k}" => @facet_filter[k] } }]#- [@MISSING_STRING] } }]
        should_arr_query
      end
    end

    # facets
    ESConfig.facets.keys.each do |facet|
      aggs[:aggs]["facet_#{facet}"] = {
        filter: {
          bool: {
            should: [
              { terms: { category: @cat_filter } }
            ]
          }
          },
        aggs: {
          count: {
            terms: {
              field: "facet.#{facet}", 
              size: 10000,
              missing: @MISSING_STRING
            }
          }
        }
      }

      if (active_facets - [facet]).any?
        aggs[:aggs]["facet_#{facet}"][:filter][:bool][:must] = (active_facets - [facet]).map do |k|
          should_arr_query = {bool: {should: []}}
          if @facet_filter[k].include? @MISSING_STRING
            should_arr_query[:bool][:should] += [{bool: {must_not: {exists: {field: "facet.#{k}"}}}}]
          end
          should_arr_query[:bool][:should] += [{ terms: { "facet.#{k}" => @facet_filter[k] } }]#- [@MISSING_STRING] } }]
          should_arr_query
        end
      end
    end

    ## Quicksearch aggregations

    aggs[:aggs][:klasses] = {
      aggs: {
        kls_count: {
          terms: {
            field: "klass", size: 10000
          }
        }
      }
    }
    aggs[:aggs][:klasses][:filter] = if @role_filter.any?
      { terms: { scope: @role_filter } }
    else
      { match_all: {} }
    end

    aggs[:aggs][:roles] = {
      aggs: {
        rl_count: {
          terms: {
            field: "scope", size: 10000
          }
        }
      }
    }
    aggs[:aggs][:roles][:filter] = if @klass_filter.any?
      { terms: { klass: @klass_filter } }
    else
      { match_all: {} }
    end

    aggs
  end
  
  def build_survey_filter
    return {} unless @campaign_slug
    sfilter = {bool: {must: [], must_not: []}}
    if @campaign_slug && @survey_status != :initial # && false
      sfilter[:bool][:must].append ({nested:{path: "survey_states",
                                          query: {
                                            bool: {
                                              must: [{match: {"survey_states.slug" => @campaign_slug}}]
                                            }
                                            } }})
      
      if @survey_status_exclude
        sfilter[:bool][:must][0][:nested][:query][:bool][:must_not] =[]
        @survey_status_exclude.each do |status|
          sfilter[:bool][:must][0][:nested][:query][:bool][:must_not].push({match: {"survey_states.status" => status}})
        end
      elsif @survey_status
        sfilter[:bool][:must][0][:nested][:query][:bool][:must].push({match: {"survey_states.status" => @survey_status}}) 
      end
    end
    if @klass_filter && @mode == :surveycounter
      sfilter[:bool][:must] += [{terms:{klass: [@klass_filter.first]}}]
    end
    return sfilter
  end


  ##### Query methods #####

  def execute_fallback
    type = []
    type += ["DigitalCollection"] if @cat_filter.include? :digital
    type += ["CollectionActivity"] if @cat_filter.include? :activity
    type += ["Person", "Organisation"] if @cat_filter.include? :actor
    type += ["SciCollection"] if @cat_filter.include? :collection

    tokens = @query.split.map { |t| "%#{t}%" }
    template = "label LIKE ?"
    (tokens.size - 1).times do
      template << " AND label LIKE ?"
    end

    if tokens.size == 0
      tokens << "%"
    end

    scope_index = User::ROLES.index(@scope)

    results = Individual.where(type: type)
      .where([template] + tokens)
      .order(:label)
      .limit(@size).offset(@from)
      .reject { |indi| User::ROLES.index(indi.visibility) > scope_index }

    if results.size > 0
      @has_results = true
      @has_more = results.size >= @size

      @results = results.each_with_index.map { |hit,num|
        hit.provide_indexdata.merge({num: @from + num})
      }
    else
      @has_results = false
      @has_more = false
      @results = []
    end

    count = Individual.where([template] + tokens)
      .group(:type).count

    @categories[:collection][:count] = count["SciCollection"] ? count["SciCollection"] : 0
    @categories[:digital][:count]    = count["DigitalCollection"] ? count["DigitalCollection"] : 0
    @categories[:activity][:count]   = count["CollectionActivity"] ? count["CollectionActivity"] : 0
    @categories[:actor][:count]      = count["Person"] ? count["Person"] : 0
    @categories[:actor][:count]      += count["Organisation"] ? count["Organisation"] : 0

    @hits = @cat_filter.inject(0) { |s,c| s + @categories[c][:count] }
  end



  ##### After query #####

  def doc2hsh doc, num=nil
    n = num ? { num: @from + num } : {}
    { id: doc["_id"],
      klass: doc["_source"]["klass"],
      scope: doc["_source"]["scope"],
      thumb: doc["_source"]["thumb"],
      headline: doc["_source"]["headline"],
      subheadline: doc["_source"]["subheadline"],
      description: doc["_source"]["description"],
      quicksearch: doc["_source"]["inline_label"]
    }.merge(n)
  end

  def extract_results
    @hits = @raw["hits"]["total"]
    @results = []

    if @hits > 0
      @has_results = true
      @has_more = @hits > @from + @size
      @raw["hits"]["hits"].each_with_index do |doc, num|
        @results << doc2hsh(doc, num)
      end
    else
      @has_results = false
      @has_more = false
    end
  end

  def extract_aggregations
    @categories.keys.each do |c|
      @categories[c][:count] = @raw["aggregations"]["cat_#{c}"]["doc_count"]
    end

    col = ICU::Collation::Collator.new("de")

    @aggregated_facets.each do |k|
      terms = {}
      @raw["aggregations"]["facet_#{k}"]["count"]["buckets"].each do |b|
        terms[b["key"]] = b["doc_count"]
      end
      @facet_filter[k].nil? || @facet_filter[k].each do |term|
        terms.delete(term)
      end
      missing = nil
      if terms.key? @MISSING_STRING
        missing = terms.delete(@MISSING_STRING)
      end
      
      terms = terms.sort { |(a,_),(b,_)| col.compare(a,b) }
      # show "missing" option only for logged in users
      if User.at_least? @scope, :member
        terms.insert(0,[@MISSING_STRING,missing]) unless missing.nil?
      end
      
      @facets[k][:terms] = Hash[terms]
    end

    @raw["aggregations"]["klasses"]["kls_count"]["buckets"].each do |b|
      @klasses[b["key"]] = b["doc_count"]
    end

    @raw["aggregations"]["roles"]["rl_count"]["buckets"].each do |b|
      @roles[b["key"].to_sym] = b["doc_count"]
    end

    # Keep activated klass filters visible even if combined with the query it yields no results
    @klass_filter.each do |kls|
      unless @klasses.keys.include? kls
        @klasses[kls] = 0
      end
    end

    # Same for roles
    @role_filter.each do |rl|
      unless @roles.keys.include? rl
        @roles[rl] = 0
      end
    end
  end
end

