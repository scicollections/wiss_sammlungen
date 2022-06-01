# Collections

class DiscoverController < ApplicationController
  
  protect_from_forgery with: :null_session, only: :json
  
  # @action GET
  # @url /discover
  # @url /discover/:categories
  def index
    # sets active state on "Entdecken" tab
    @menu_tab_discover_active = true

    @search = Searcher.new

    conf = {
      query: discover_params[:q],
      scope: current_user.role,
      facet_filter: discover_params[:f]
    }

    if discover_params[:categories]
      conf[:cat_filter] = discover_params[:categories].split(",")
    else
      # Wenn keine Kategorie angegeben ist nur Sammlungen anzeigen
      conf[:cat_filter] = [:collection]
    end

    @search.configure conf
    if discover_params[:afk]
      @search.add_facet discover_params[:afk], discover_params[:afv]
    end

    if discover_params[:rfk]
      @search.remove_facet discover_params[:rfk], discover_params[:rfv]
    end

    if request.xhr?
      # discover_params[:p] is here an offset
      @search.configure from: discover_params[:p]
      @search.execute
      render partial: "results"
    else
      # discover_params[:p] is here: Select from 0 to p + 50 
      if discover_params[:p]
        size = discover_params[:p].to_i
        size = [size, 50].min
      end
      @search.configure from: 0
      @search.configure size: size + @search.size if size

      @search.execute

      # Such-Tracking
      url = "#{request.original_url.encode("UTF-8", :invalid => :replace, :undef => :replace)}&notrack"
      SearchLog.create sid: request.session_options[:id], query: @search.q,
        cat_filter: @search.cat_filter.to_s, facet_filter: @search.facet_filter.to_s,
        hits: @search.hits, url: url unless discover_params.has_key?(:notrack) if request.session_options[:id]

      cats = @search.cat_filter.map { |cf| @search.categories[cf][:name] }.join(", ")
      if @search.q.size > 0
        page_title "#{cats}: #{@search.q}"
      else
        page_title cats
      end

      # Speichere Suchparameter in Session
      session[:last_search] = @search.params

      # Bei Fallback-Suche eine Benachrichtigung raussschicken
      if @search.fallback
        logger.error "Discover fallback active. ElasticSearch is not available"
        # it's neccessary to store the return value in 'mailer'. If not, no emails are sent. 
        # This could be the result of async mail delivery in another thread
        mailer = ErrorMailer.report_search_error request.env, @search.fb_exception, @search
        logger.info "ErrorMailer Object is " + mailer.to_s
      end
      
    end
  end
  
  # @action POST
  # @url /discover
  # @api
  #
  # @example JSON API
  #   {
  #     term: "Erika Musterfrau",       #(query term)
  #     category: "collection",         #(see ESConfig.categories)
  #     from: 0,                        #offset
  #     size: 50,                       #result size
  #     facets: {                       # see ESConfig.facets
  #       place: ["Berlin","Hamburg"],
  #       collectiontype: "Geschichte & Archäologie"
  #     }
  #   }
  # 
  # @see ESConfig
  def json
    @search = Searcher.new
    http_auth
    conf = {
      query: discover_params[:term],
      scope: current_user.role,
      facet_filter: discover_params[:facets]
    }

    if discover_params[:category]
      conf[:cat_filter] = discover_params[:category].split(",")
    else
      # Wenn keine Kategorie angegeben ist nur Sammlungen anzeigen
      conf[:cat_filter] = [:collection]
    end

    conf[:size] = discover_params[:size] || 100
    conf[:from] = discover_params[:from] || 0
    
    @search.configure conf

    @search.execute
    
    jsonresults = @search.results.collect{|h| h.slice(:id,:klass,:quicksearch)}
    jsonresults.each do |h|
      h[:class] = h.delete :klass
      h[:class_specific_localised] = I18n.t h[:class]
      h[:label] = h.delete :quicksearch
      h[:purl] = "https://#{Maya::Application.config.mailhost["production"]}/#{h[:class]}/#{h[:id]}"
    end
    render json: {
      summary: {
        from: conf[:from],
        size: @search.results.size,
        facets: conf[:facet_filter],
        term: conf[:query],
        category: conf[:cat_filter]
      },
      results: jsonresults
    }
    
  end

  # @action GET
  # @url /discover/:categories/:key
  def facets
    @search = Searcher.new
    @key = discover_params[:key].to_sym

    unless ESConfig.facets.keys.include? @key
      raise ErrorController::NoFacetKey, "No such facet key exists: #{@key}"
    end

    conf = {
      query: discover_params[:q],
      scope: current_user.role,
      facet_filter: discover_params[:f],
      aggregated_facets: @key
    }
    if discover_params[:categories]
      conf[:cat_filter] = discover_params[:categories].split(",")
    else
      # Wenn keine Kategorie angegeben ist nur Sammlungen anzeigen
      conf[:cat_filter] = [:collection]
    end
    @search.configure conf
    @search.execute

    # Wenn keine Ergebnisse vorliegen
    unless @search.has_results
      # Wechsle in die erste Kategorie mit Ergebnissen
      cat = @search.categories.keys.detect { |k| @search.categories[k][:count] != 0 }
      if cat
        @search.configure cat_filter: cat
        @search.execute
      elsif discover_params[:lq] != discover_params[:q]
        # Falls gar keine Kategorie Ergebnisse hatte und der Suchquery geändert wurde:
        # Facetten-Filter löschen und erneut probieren
        @search.facet_filter = nil
        @search.execute
        unless @search.has_results
          # Falls immer noch keine Ergebnisse vorliegen, erneut nach Kategorien mit Ergebnissen suchen
          cat = @search.categories.keys.detect { |k| @search.categories[k][:count] != 0 }
          if cat
            @search.configure cat_filter: cat
            @search.execute
          end
        end
      end
    end

    render partial: "filterlist"
  end

  # @action GET
  # @url /navigation/:hit
  def navigation
    hit = discover_params[:hit] ? discover_params[:hit].to_i : 0
    navigator = Navigator.new session
    dest = navigator.get_route hit, current_user.role
    if dest.present?
      redirect_to dest
    else
      flash[:error] = "Ihre vorherigen Suchergebnisse sind leider nicht mehr verfügbar."
      redirect_to discover_path
    end
  end

  # @action GET
  # @url /quicksearch?q=searchstring
  #
  # Search in individuals' inline labels by string, e.g. "Pete Mü" or "Müller, Peter".
  #
  # @return [Array<Hash>] A list of the matching individuals' names and resource links.
  def quicksearch
    s = Searcher.new
    conf = {
      query: discover_params[:q],
      size: 15,
      mode: :quicksearch,
      scope: current_user.role,
      sort_by_relevance: true
    }
    s.configure conf
    s.execute

    jsn = s.results.map do |r|
      { label: r[:quicksearch], link: "/#{r[:klass]}/#{r[:id]}" }
    end

    render json: jsn
  end
  
  # GET /opensearch.xml
  def opensearch
      # fixes Firefox "Firefox could not download the search plugin from:"
      response.headers["Content-Type"] = 'application/opensearchdescription+xml'
      render "opensearchdescription.xml", :layout => false
  end
  
  private
    def discover_params
      params.permit!
      return params.to_h
    end
end
