# Indexer

require 'elasticsearch'
require Rails.root.join("config", "elasticsearch")
require 'thread'
require 'timeout'
require 'benchmark'

class Indexer
  def self.recreate_index
    ActiveRecord::Base.logger.level = 1
    puts "Indexer: Recreate whole searchindex with alias #{ESConfig.connection['searchindex']} using prefix #{ESConfig.connection['prefix']}"

    configure
    index = create_index @alias
    create_bulkdata index
    old_indices = update_alias @alias, index
    delete_indices old_indices

  end
  
  def self.delayed_update
    t = Thread.new do
      File.open(Rails.root.join("tmp","index_update.lock"), File::RDWR|File::CREAT, 0644) do |f|
        begin
          # Auf Lockfile warten
          Timeout::timeout(5*60) { f.flock(File::LOCK_EX) }
        rescue Timeout::Error => e
          Logger.new("log/indexer.log").warn("Couldn't acquire exclusive lock (Timeout of 5 min reached)")
        else
          # Connection Pool um verwaiste Verbindungen zu verhindern:
          # https://bibwild.wordpress.com/2014/07/17/activerecord-concurrency-in-rails4-avoid-leaked-connections/
          ActiveRecord::Base.connection_pool.with_connection do |con|
            update_index
          end
        end
      end
    end
  end
  
  
  private

  def self.update_index
    configure

    begin
      @logger.info "Started indexupdate on #{@alias}"

      now = Time.current
      revs = Revision.where(indexed: [nil, false])
      
      # user events (survey stuff)
      ues = UserEvent.where(indexed: [nil, false, 0])
      target_user_ids = ues.collect &:target_user_id
      person_ids = User.where(id: target_user_ids).collect &:individual_id

      @logger.debug "Updating #{revs.size} Revisions"
      @logger.debug "Updating #{ues.size} UserEvents"

      if revs.any? or ues.any?
        ids = (revs.map(&:individual_id) + person_ids).uniq
        
        # if in a campaign, include campaign targets for user event people
        if Campaign.current
          for p_id in person_ids
            target_ids = Campaign.current.resolve_indis_for_person(Person.find(p_id)).collect &:id
            ids += target_ids
          end
        end

        update ids

        # Nur die Revisionen als indexed markieren, die innerhalb der Updatevorgangs nicht geändert wurden
        count = 0
        revs.each do |old_rev|
          new_rev = Revision.find(old_rev.id) rescue nil
          if new_rev && old_rev.attributes == new_rev.attributes
            new_rev.update_column(:indexed, true)
            count += 1
          end
        end
        ues.update_all(indexed: true)
        @logger.debug "Updated #{count} of #{revs.size} Revisions"
      end
    rescue Exception => e
      @logger.warn "Encountered Exception: #{e}"
      raise e
    end
  end

  def self.update ids
    # Zuerst die IDs selbst updaten
    @logger.debug "Updating IDs: #{ids}"
    bulkdata = []
    ids.each do |id|
      begin
        indi = Individual.find(id)
        bulkdata << {index: {_index: @alias, _type: "individual", _id: id, data: indi.provide_indexdata}} if indi.has_view? and not indi.weak?
      rescue ActiveRecord::RecordNotFound => e
        bulkdata << {delete: {_index: @alias, _type: "individual", _id: id}}
      end
    end
    @esc.bulk body: bulkdata if bulkdata.size > 0

    # Nun alle verknüpften IDs suchen und updaten
    @logger.debug "Query ES for related ids"
    
    # Notfallmaßnahme
    #@logger.warn "Canceling updating related ids as this query doesn't work at the moment."
    #@logger.warn "See bug #1487"
    #@logger.warn " "
    #return
    
    query = { query: { bool: { filter: { terms: { related_ids: ids }}}}}

    res = @esc.search index: @alias, scroll: "5m", size: 50, body: query

    while res = @esc.scroll(scroll_id: res["_scroll_id"], scroll: "5m") and not res["hits"]["hits"].empty?
      bulkdata = []
      res["hits"]["hits"].each do |hit|
        begin
          indi = Individual.find(hit["_id"])
          if indi.has_view? and not indi.weak?
            bulkdata << {index: {_index: @alias, _type: "individual", _id: hit["_id"], data: indi.provide_indexdata}}
          end
        rescue ActiveRecord::RecordNotFound => e
          # individual got deleted
          bulkdata << {delete: {_index: @alias, _type: "individual", _id: hit["_id"]}}
        end
      end
      @esc.bulk body: bulkdata if bulkdata.size > 0
      @logger.debug "Updating #{bulkdata.size} related docs"
    end
  end

  def self.configure
    @esc ||= Elasticsearch::Client.new host: ESConfig.connection["host"], port: ESConfig.connection["port"]
    @alias ||= "#{ESConfig.connection['prefix']}_#{ESConfig.connection['searchindex']}"
    @logger ||= Logger.new("log/indexer.log")
    
    # variable for caching class hierarchies for indexing hierarchical facet values
    @hierarchies = {} 
  end

  def self.create_index basename
    indexname = "#{basename}_#{Time.now.to_i}"

    puts "Indexer: Creating new index with name #{indexname}"
    puts "... and mappings #{ESConfig.mappings}"

    @esc.indices.create index: indexname,
      body: {
        settings: ESConfig.index_settings,
        mappings: ESConfig.mappings
      }

    return indexname
  end

  def self.create_bulkdata index
    puts "Indexer: Extracting initial searchdata for Elasticsearch"
    time = Benchmark.measure do
      timestamp = DateTime.now

      count = 0
      Individual.find_in_batches do |batch|
        bulkdata = []
        batch.each do |i|
          if i.has_view? and not i.weak?
            puts "... #{i.id} #{i.type} #{i.label}"
            bulkdata << {index: {_index: index, _type: "individual", _id: i.id, data: i.provide_indexdata(mode: :jump)}}
          end
        end
        puts "BULK ... sending batch with #{bulkdata.size} individuals to Elasticsearch ..."
        @esc.bulk body: bulkdata if bulkdata.size > 0
        count += bulkdata.size
      end
    
      # set revisions to indexed when they were created before the timestamp
      revs = Revision.where("indexed = 0 AND created_at < ?",timestamp)
      revs.update_all(indexed: 1)
      # save for user events
      ues = UserEvent.where("indexed = 0 AND created_at < ?",timestamp)
      ues.update_all(indexed: 1)
      puts "Indexer: Done! Imported #{count} individuals to elasticsearch"
    end
    puts "Benachmark: #{time}"
  end

  def self.update_alias index_alias, new_index
    # Returns list of old (and now probably unused) indices

    puts "Indexer: Update alias #{index_alias} to #{new_index}:"
    res = []
    if @esc.indices.exists_alias?({name: index_alias})
      res = @esc.get index: "*", type: "_alias", id: index_alias
      puts "Indexer: Remove alias for indices #{res.keys}"

      # Switch alialized index with zero-downtime:
      acts = res.keys.each.map { |i| { remove: { index: i, alias: index_alias } } }
      acts << { add: { index: new_index, alias: index_alias } }
      @esc.indices.update_aliases body: { actions: acts }
    else
      @esc.indices.put_alias index: new_index, name: index_alias
    end
    puts "Indexer: Added alias for index #{new_index}"

    return res.size > 0 ? res.keys : []
  end

  def self.delete_index index
    puts "Indexer: Deleting Index #{index}"
    index && @esc.indices.delete(index: index)
  end

  def self.delete_indices indices
    puts "Indexer: Deleting #{indices.size} indices:"
    indices.each { |i| delete_index i }
  end
end
