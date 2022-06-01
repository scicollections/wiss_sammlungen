# Helper methods to load and display info texts.
module InfoHelper
  # Info texts will be stored in this hash.
  @@info = {
    individual: {},
    predicate: {},
    discover: {},
    property_type: {}
  }

  # Trigger update of info texts.
  def self.read_files!
    mep = [
      [:individual ,'app/info/individuals.yml'],
      [:predicate, 'app/info/predicates.yml'],
      [:discover, 'app/info/discover.yml'],
      [:property_type, 'app/info/property_types.yml']
    ]
    mep.each do |key, path|
      begin
        content = YAML.load_file(path)
        @@info[key] = content if content
      rescue Errno::ENOENT
        puts "Oh, dang - could not load missing infosystem-file #{path}."
      end
    end
  end
  # The Info-Text files will be loaded only on server start and never again
  # afterwards, otherwise each request would trigger 3 additional file accesses!
  read_files!

  # Get textual information about this Individual class.
  #
  # @param individual_or_class An instance of Individual OR a subclass of Individual.
  #
  # @return [String]
  def individual_info individual_or_class
    klass = get_class_name individual_or_class

    # TODO Refactor this file to use Hash#dig
    if @@info[:individual][klass].present? \
      && @@info[:individual][klass]["info"].present?
      @@info[:individual][klass]["info"]
    else
      ""
    end
  end

  # Get textual information about this predicate, optionally pass an
  # individual to get specific predicate info text in the context of this
  # individual's class.
  #
  # @param predicate [String]
  # @param individual_or_class [Class, Individual] If present, infotext for this predicate is
  #   looked up in individual class's info text section first; if none is found
  #   the more general info text is returned.
  #
  # @return [String]
  def predicate_info predicate, individual_or_class: nil
    if individual_or_class.present? && predicate.present?
      klass = get_class_name individual_or_class
      if @@info[:individual][klass].present? \
        && @@info[:individual][klass]["predicates"].present? \
        && @@info[:individual][klass]["predicates"][predicate].present? \
        && @@info[:individual][klass]["predicates"][predicate]["info"].present?
        individual_specific_predicate_info = @@info[:individual][klass]["predicates"][predicate]["info"]
      end
    end

    if predicate.present? \
      && @@info[:predicate][predicate].present? \
      && @@info[:predicate][predicate]["info"].present?
      general_predicate_info = @@info[:predicate][predicate]["info"]
    end

    individual_specific_predicate_info || general_predicate_info || ""
  end
  
  # Get textual information about this predicate, optionally pass an
  # individual to get specific predicate info text in the context of this
  # individual's class.
  #
  # @param predicate [String]
  # @param individual_or_class [Class, Individual] If present, infotext for this predicate is
  #   looked up in individual class's info text section first; if none is found
  #   the more general info text is returned.
  # @param info_tag [String] Can be "info","edit" or "survey"
  #
  # @return [String]
  def predicate_info_by_tag predicate, individual_or_class: nil, info_tag: "info"
    if individual_or_class.present? && predicate.present?
      klass = get_class_name individual_or_class
      if @@info[:individual][klass].present? \
        && @@info[:individual][klass]["predicates"].present? \
        && @@info[:individual][klass]["predicates"][predicate].present? \
        && @@info[:individual][klass]["predicates"][predicate][info_tag].present?
        individual_specific_predicate_info = @@info[:individual][klass]["predicates"][predicate][info_tag]
      end
    end

    if predicate.present? \
      && @@info[:predicate][predicate].present? \
      && @@info[:predicate][predicate][info_tag].present?
      general_predicate_info = @@info[:predicate][predicate][info_tag]
    end

    individual_specific_predicate_info || general_predicate_info || ""
  end

  # Get textual information about this Facet or Category in discover search context.
  # Defined in app/info/discover.yml
  #
  # @param facet_or_category [#to_s] Facet or category, according to ESConfig.categories/facets.
  #
  # @return [String]
  def discover_info facet_or_category
    @@info[:discover][facet_or_category.to_s] || ""
  end

  # Get textual information about this predicate in edit context,
  # optionally pass an individual to get specific predicate info text in the
  # edit context of this individual's class.
  #
  # @param predicate [String]
  # @param individual_or_class [Class, Individual] If present, infotext for this predicate is
  #   looked up in individual class's info text section first; if none is found
  #   the more general info text is returned.
  #
  # @return [String]
  def edit_info predicate, individual_or_class: nil
    if individual_or_class.present? && predicate.present?
      klass = get_class_name individual_or_class
      if @@info[:individual][klass].present? \
        && @@info[:individual][klass]["predicates"].present? \
        && @@info[:individual][klass]["predicates"][predicate].present? \
        && @@info[:individual][klass]["predicates"][predicate]["edit"].present?

        individual_specific_predicate_info = @@info[:individual][klass]["predicates"][predicate]["edit"]
      end
    end

    if predicate.present? \
      && @@info[:predicate][predicate].present? \
      && @@info[:predicate][predicate]["edit"].present?

      general_predicate_info = @@info[:predicate][predicate]["edit"]
    end

    edit_info = individual_specific_predicate_info || general_predicate_info || ""
    predicate_info = predicate_info(predicate, individual_or_class: individual_or_class)

    property_type_info = property_info_by_predicate predicate

    if individual_or_class.present?
      if individual_or_class.is_a?(Individual)
        range_type_info = range_type_info(individual_or_class.class, predicate)
      elsif individual_or_class.is_a?(Class)
        range_type_info = range_type_info(individual_or_class, predicate)
      end
    end

    [
      predicate_info,
      edit_info,
      property_type_info,
      range_type_info
    ].select{|el| el.present?}.join('<p>')
  end

  # Get textual information about this Property class.
  #
  # @param property_or_class Instance of subclass of Property or subclass itself.
  #
  # @return [String]
  def property_info property_or_class
    if property_or_class.is_a? Class
      klass = property_or_class.to_s
    elsif property_or_class.is_a? Property
      klass = property_or_class.class.to_s
    else
      return ""
    end

    if @@info[:property_type][klass].present?
      return @@info[:property_type][klass]
    else
      return ""
    end
  end

  # Get textual information about the Property class of this predicate.
  #
  # @param predicate [String]
  #
  # @return [String]
  def property_info_by_predicate predicate
    klass = Ontology.resolve_property_class predicate.to_sym
    property_info klass
  end

  # Get textual information about the defined Types of the Range of this
  # predicate, if defined and present in individuals.yml as (Individual:edit).
  #
  # @param klass [Class] The individual class with the predicate.
  # @param predicate [String]
  #
  # @return [String]
  def range_type_info klass, predicate
    klass_name = klass.to_s
    ret = []

    if predicate.present? \
      && klass.present? \
      && klass.predicates.present? \
      && klass.predicates[predicate].present? \
      && klass.predicates[predicate][:range].present? \

      [ klass.predicates[predicate][:range] ].flatten.each do |klass_name|
        if @@info[:individual][klass_name].present? \
          && @@info[:individual][klass_name]["edit"].present?

          ret.push(@@info[:individual][klass_name]["edit"])
        end
      end
    end
    ret.join("<p>")
  end

  private

  # Internal: Extract class name from Individual OR Class.
  #
  # Returns a Class name as String.
  def get_class_name individual_or_class
    if individual_or_class.is_a? Individual
      individual_or_class.class.to_s
    elsif individual_or_class.is_a? Class
      individual_or_class.to_s
    else
      raise ArgumentError, "expected class or instance of Individual as argument"
    end
  end
end
