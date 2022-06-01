# Indexable
require Rails.root.join("config", "elasticsearch")
require 'benchmark'

module Indexable
  module ClassMethods
    # Accessor für provide_indexdata
    def indexmapping
      @indexmapping
    end

    def category name
      set_indexmapping :category, name
    end

    def headline *args
      add_indexmapping :headline, args
    end

    def subheadline *args
      add_indexmapping :subheadline, args
    end

    def description *args
      add_indexmapping :description, args
    end

    def facet name, *args
      @indexmapping ||= {}
      @indexmapping[:facet] ||= {}
      @indexmapping[:facet][name] ||= {path: []}
      if args.last.is_a?(Hash)
        opts = args.pop
      end 
      @indexmapping[:facet][name][:path] << args
      @indexmapping[:facet][name].merge! (opts || {})
    end
    
    def separator searchfield, sep
      @indexmapping ||= {}
      @indexmapping[:separator] ||= {}
      @indexmapping[:separator][searchfield] = sep
    end

    private

    def set_indexmapping searchfield, args
      @indexmapping ||= {}
      @indexmapping[searchfield] = args
    end

    def add_indexmapping searchfield, args
      @indexmapping ||= {}
      @indexmapping[searchfield] ||= []
      @indexmapping[searchfield] << args
    end

  end

  module InstanceMethods
    def provide_indexdata mode: :jump
      # Standard Indexdaten, die jedes Individual hat
      indexdata = {
        id: id,
        klass: self.class.name,
        #scope: User::ROLES.drop(User::ROLES.index(visibility)), # Array of roles >= visibility
        scope: visibility,
        related_ids: [id],
        label: label,
        inline_label: inline_label,
        thumb: thumb ? thumb.to_i : 0,
        survey_states: self.survey_states # Do NOT collect survey states for normal indexing/updating as it's rather slow
      }
      indexdata[:same_as] = self.safe_values("same_as")

      # Gibt es ein Mapping für weitere Suchdaten?
      if self.class.indexmapping ||
          self.class.ancestors.select { |a| a < Individual && a.indexmapping}.any?
        mp = self.class.indexmapping || {}

        # Indexmappings von Superklassen übernehmen
        self.class.ancestors
          .select { |a| a < Individual && a.indexmapping}
          .map(&:indexmapping)
          .each do |am|
            mp = am.deep_merge(mp) do |k,v1,v2|
              if v1.is_a?(Array) && v2.is_a?(Array)
                # Merge if both are Arrays
                (v1 + v2).compact.uniq
              else
                # Don't overwrite with nil
                v2.nil? ? v1 : v2
              end
            end
        end

        # Suchkategorie hinzufügen, falls gegeben
        indexdata[:category] = mp[:category] if mp[:category]
        
        hidden_data = []

        ids = [id]

        # Volltext-Suchfelder abfragen
        %i(headline subheadline description).each do |searchfield|
          next unless mp[searchfield]
          data = []
          mp[searchfield].each do |path|
            rids, rdata = resolve_index_values(path)
            ids += rids
            data += rdata
          end

          sep = mp[:separator] && mp[:separator][searchfield] ? mp[:separator][searchfield] : ", "
          indexdata[searchfield] = data.compact.uniq.join(sep)
        end

        # Facetten-Felder abfragen
        if mp[:facet]
          indexdata[:facet]  ||= {}

          # TODO: Alle keys durchgehen
          mp[:facet].each do |facet, facethash|
          #ESConfig.facets.keys.each do |facet|
            follow_hierarchy = facethash[:follow_hierarchy]
            include_hidden = facethash[:include_hidden]
            data = []
            
            mp[:facet][facet][:path].each do |path|            
              rids, rdata, hidden_rdata = jump_index_values(path, value_callback: :facet_value, follow_hierarchy: follow_hierarchy, include_hidden: include_hidden)
              ids += rids
              data += rdata
              hidden_data += hidden_rdata if hidden_rdata
            end if mp[:facet][facet]
            indexdata[:facet][facet] = data.compact.uniq
          end
        end
        # Related IDs einpflegen
        indexdata[:related_ids] = ids.compact.uniq
        indexdata[:hidden] = hidden_data.flatten.compact.uniq
      end
      
      return indexdata
    end

    private
    
    # @return [Array<Integer>],[Array<String>]
    def jump_index_values path, value_callback: :index_value, follow_hierarchy: false, include_hidden: false
      ids = [self.id]
      ids_accu = ids.clone
      synonyms = []
      while !path.empty?
        predicate = path[0]
        path = path[1..]
        unless predicate == :self or predicate.is_a? String
          props = Property.where(subject_id: ids, predicate: predicate.to_s)
          ids = props.collect &:objekt_id
        end
        ids_accu += ids.compact
      end
    
      if predicate.is_a? String
        return ids_accu, [predicate], nil
      end
    
      # virtual props
      # return ids_accu, Individual.where(id: ids).map{|indi| indi.send(predicate)}.map(&value_callback).map(&:strip)
      if ids.compact.blank?
        # data properties
        return ids_accu, props.map(&:index_value).map(&:strip), nil
      else
        # objekt properties
        indis = Individual.where(id: ids)
        if follow_hierarchy
          klasses = indis.collect{|iv| iv.class}.uniq
          raise "Too many classes" if klasses.length > 1
          klass = klasses.first
          
          hierarchy_items = nil
          if Indexer.instance_variable_get(:@hierarchies) 
            # called via Indexer
            if Indexer.instance_variable_get(:@hierarchies)[klass]
              hierarchy_items = Indexer.instance_variable_get(:@hierarchies)[klass] 
            else
              hierarchy_items = klass.default_hierarchy.items
              Indexer.instance_variable_get(:@hierarchies)[klass] = hierarchy_items
            end
          else
            # not called via Indexer
            hierarchy_items = klass.default_hierarchy.items
          end

          ancestors = []
          indis.each do |value|
            item = hierarchy_items.find{|item| item.indi == value}
            ancestors += item.ancestors
          end
          indis += ancestors
          indis.uniq!
          
        end
        
        if include_hidden
          synonymProps = Property.where(subject_id: ids, predicate: include_hidden)
          synonyms += synonymProps.map(&:index_value).map(&:strip)
        end
        
        ids_accu += indis.collect(&:id)
        return ids_accu.uniq, indis.map(&value_callback).map(&:strip), synonyms
      end
    
    end
    
    # @return [Array<Integer>],[Array<String>]
    def resolve_index_values path, recievers=[self], value_callback: :index_value, follow_hierarchy: false, include_hidden: false
      if path.first.is_a? String
        return recievers.map(&:id), [path.first]
      end

      if path.first == :self
        return recievers.map(&:id), recievers.map(&value_callback).map(&:strip)
      end

      if path.first == :label
        return recievers.map(&:id), recievers.map(&:label).map(&:strip)
      end

      if path.first == :inline_label
        return recievers.map(&:id), recievers.map(&:inline_label).map(&:strip)
      end

      # if not self or label, path.first should be a property
      # also all recievers should be of the same type
      prop = recievers.first.predicates[path.first.to_s]

      raise "Incorrect argument: Property not found!" if prop.nil?

      # accumulate all properties related to given recievers
      if prop[:cardinality] == 1
        props = recievers.map(&path.first)
      else
        props = []
        recievers.each do |r|
          props += r.send(path.first)
        end
      end
      props.compact!

      # found properties?
      return recievers.map(&:id), [] unless props.size > 0

      if prop[:type] == :objekt
        #properties point to individuals
        ivs = props.map(&:value)

        if path.size > 1
          # chain more properties, if path still contains more
          ids, values = resolve_index_values(path.drop(1), ivs, value_callback: value_callback, follow_hierarchy: follow_hierarchy, include_hidden: false)
          return recievers.map(&:id) + ids, values
        else
          if follow_hierarchy
            ivs.each do |value|
              hierarchy_items = value.class.default_hierarchy.items
              item = hierarchy_items.find{|item| item.indi == value}
              ancestors = item.ancestors
              ivs += ancestors
              ivs.uniq!
            end
          end
          # get indexvalues of individuals
          return recievers.map(&:id) + ivs.map(&:id), ivs.map(&value_callback).map(&:strip)
        end
      else
        # data properties
        return recievers.map(&:id), props.map(&:index_value).map(&:strip)
      end
    end
  end
end
