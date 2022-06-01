# For functionality that relates to properties like "has_part" and "narrower" that induce a
# hierarchy of individiduals.
module Hierarchical
  module ClassMethods
    # This provides a "default_hierarchy" and a "property_hierarchy" class method.
    #
    # @param predicate [String] The predicate the default hierarchy should be based on.
    #
    # @!macro [attach] default_hierarchy_predicate
    #   @!method default_hierarchy
    #     @return [IndividualHierarchy] The hierarchy based on the predicate "$1".
    #   @!method property_hierarchy(properties)
    #     @return [Array<Array<(Property, Integer)>>] The property hierarchy based on the predicate
    #       "$1".
    def default_hierarchy_predicate predicate
      define_singleton_method(:default_hierarchy) do
        IndividualHierarchy.new(self, predicate)
      end

      define_singleton_method(:property_hierarchy) do |properties|
        # Gibt nur Array von Tupeln der Form [property, level] zurück, da wir hier die
        # broader und narrower Concepts nicht brauchen, da wir inline nicht filtern.
        indi_ids = properties.map(&:objekt_id)
        ih = IndividualHierarchy.new(where(id: indi_ids).order(:inline_label), predicate)

        # Possible optimization: Tell the IndividualHierarchy not to collect the descendants,
        # as we don't need them anyway.
        ih.items.map do |item|
          property = properties.find { |prop| prop.objekt == item.indi }
          [property, item.level]
        end
      end
      
      define_singleton_method(:broader_property_hierarchy) do |properties|
        # Gibt nur Array von Tupeln der Form [property, level] zurück, da wir hier die
        # broader und narrower Concepts nicht brauchen, da wir inline nicht filtern.
        indi_ids = properties.map(&:objekt_id)
        ih = IndividualHierarchy.new(where(id: indi_ids).order(:inline_label), predicate, true)
        
        
        # Possible optimization: Tell the IndividualHierarchy not to collect the descendants,
        # as we don't need them anyway.
        ih.items.map do |item|
          property = properties.find { |prop| prop.objekt == item.indi }
          unless property
            property = Property.new(subject_id: properties.first.subject_id,
                                            predicate: properties.first.predicate,
                                            objekt_id: item.indi.id,
                                            type: "PropertyObjekt")
          end
          [property, item.level]
        end
      end

      # Adds the ids that would introduce circles to the list of illegal objekt ids.
      #
      # (This needs to be here, instead of being a regular instance method defined in this
      # concern, to be evaluated *later* than Individual#illegal_objekt_ids_with_reasons.
      # Otherwise, "super" doesn't work.)
      define_method(:illegal_objekt_ids_with_reasons) do |predicate|
        illegals = super(predicate)
        if predicates[predicate][:hierarchical]
          reason = "Diese Auswahl würde einen Kreis erzeugen und ist daher nicht verfügbar."
          IndividualHierarchy
            .new(self, inverse_of(predicate))
            .items
            .each { |item| illegals[item.indi.id] << reason }
        end
        illegals
      end
    end
  
    # Whether the individual class has a hierarchy.
    #
    # @note Should be overriden by subclasses.
    #
    def hierarchical?
      false
    end
  
    # Whether the individual classes' hierarchy is a classification
    # and should therefore be displayed hierarchical in property_group.html.slim
    #
    # @note Should be overriden by subclasses.
    #
    def classifying?
      false
    end
    
  end
end
