# Singleton class responsible to store information about predicate configurations for individual
# classes.
class Ontology
  # Hash to store registered predicates.
  @@predicates = Hash.new { |h, k| h[k] = {} } # Default-Wert ist {} (statt nil)

  # Classes corresponding to the type shorthands.
  @@property_types = {
    string: PropertyString,
    text: PropertyText,
    integer: PropertyInteger,
    float: PropertyFloat,
    bool: PropertyBool,
    date: PropertyDate,
    objekt: PropertyObjekt,
    url: PropertyUrl,
    email: PropertyEmail,
    phone: PropertyPhone,
    select_option: PropertySelectOption
  }

  # Specification of ontology constants, i.e. individuals, that are not
  # deletable; entries are structured like:
  #
  #     type_name: { label => descriptive_id }
  #
  # This hash is used by ensure_ontology_constants.
  @@ontology_constants = {
    "PlaceType" => {
      "Stadt" => "City",
      "Bundesland" => "State",
      "Staat" => "Country",
      "Adresse" => "Address",
    },
    "ConceptScheme" => {
      "Art der Aktivität" => "ActivityType",
      "Bildqualität" => "ImageQuality",
      "Einrichtungsart" => "OrganisationType",
      "Fachgebiet" => "Subject",
      "Format" => "DigitalReproductionType",
      "Lebewesen" => "LivingBeing",
      "Objektgattung" => "ObjectGenre",
      "Ortstyp" => "PlaceType",
      "Sammlungsart" => "CollectionType",
      "Wissenschaftliche Funktion" => "CollectionRole",
    },
    "OrganisationType" => {
      "Universität" => "University",
      "Sammlungskoordination" => "CollectionCoordination",
      "Fördereinrichtung" => "FundingOrganisation",
      "Kunst- oder Musikhochschule" => "UniversityOfTheArtsOrMusic",
      "Hochschule" => "HigherEducationInstitution"
    }
  }

  # Registering Methods

  # Register a predicate.
  def self.register_predicate klass, predicate, type, options
    @@predicates[klass.name][predicate] = {type: type}.merge!(options)
  end

  # Information Methods

  # @param type [Symbol] One of the property type shorthands.
  # @return [Class]
  def self.resolve_property_class type
    @@property_types[type] || PropertyString
  end

  # Get the predicate configuration for a individual class.
  def self.predicates klass, with_ancestors=true
    hash = {}

    # Ancestors sind alle Oberklassen und -module, in aufsteigender Reihenfolge.
    if with_ancestors
      classes = [klass] + klass.ancestors
    else
      classes = [klass]
    end

    # Wollen nur die Klassen, die von Individual abstammen (und
    # Individual selbst).
    rahel_classes = classes.find_all { |x| x <= Individual }

    # Wir drehen jetzt die Reihenfolge um, damit die Oberklassen zuerst kommen.
    # So werden Predicates, die auf tieferer Ebene erneut definiert werden,
    # wieder überschrieben.
    rahel_classes.reverse!

    rahel_classes.each { |x| hash.merge! @@predicates[x.name] }
    hash
  end

  # Print a list of predicates.
  def self.predicates_list klass
    x = ""
    (self.predicates klass).each do |pr,d|
      x += pr + ":\n"
    end
    puts x
    nil
  end

  # @return [Array<(Array<Class>, Array<Class>)>] The types the user can create as a hierarchy and
  #   as a flat list.
  def self.creatable_types user
    Rails.application.eager_load!
    @collator = ICU::Collation::Collator.new("de")

    alphabetical = Individual
        .descendants
        .select { |klass| klass.has_view? && !klass.weak? && user.can_create_individual?(klass) && klass.name.split("::")[0] != "Rahel" }
        .sort { |a,b| @collator.compare(I18n.t(a.name), I18n.t(b.name)) }

    tree = build_tree Individual, user
    hierarchical = flatten_tree tree

    [alphabetical, hierarchical]
  end


  # Ensures the existence of the specified ontology constants, creates those
  # which are not already present in the database. Existing Individuals that
  # are of the specified type and carry the specified label but lack a
  # descriptive_id, are augmented with the specified descriptive_id, rather
  # than creating a new Individual.
  def self.ensure_ontology_constants
    @@ontology_constants.each do |type, values|
      values.each do |label, descriptive_id|
        indi_with_did = Individual.find_by(descriptive_id: descriptive_id)
        unless indi_with_did
          indi_without_did = Individual.find_by(label: label, type: type)
          if indi_without_did
            indi_without_did.update(descriptive_id: descriptive_id)

            puts "OntologyConstants: Augmented Individual #{label}"\
              "(#{indi_without_did.id}) of type #{type} with descriptive_id '"\
              "#{descriptive_id}'"
          else
            indi = Individual.create(label: label, type: type, descriptive_id: descriptive_id)

            puts "OntologyConstants: Created Individual #{label}"\
              "(#{indi.id}) of type #{type} with descriptive_id '"\
              "#{descriptive_id}'"
          end
        end
      end
    end
    return true
  end

  private
  def self.build_tree root, usr, lyr=0, anc=[]
    tree = root.direct_descendants

    # Rahel-Klassen rausfiltern
    while (tree.select { |klass| klass.name.split("::")[0] == "Rahel" }.any?)
      tree = tree.collect { |klass| klass.name.split("::")[0] == "Rahel" ? klass.direct_descendants : klass }.flatten
    end

    # Sortieren und in praktischen Hash überführen
    tree = tree
      .sort { |a,b| @collator.compare(I18n.t(a.name), I18n.t(b.name)) }
      .map { |klass| {klass: klass, layer: lyr, ancestors: anc, descendants: [], creatable: (klass.has_view? && !klass.weak? && usr.can_create_individual?(klass))} }

    # Rekursiv die Kindklassen zusammensuchen
    tree.each do |t|
      if t[:klass].direct_descendants.any?
        t[:descendants] = build_tree t[:klass], usr, lyr+1, anc+[t[:klass]]
      end
    end

    # Knoten die nicht erstellbar sind und keine Kindknoten haben aus dem Baum entfernen
    tree.reject! do |t|
      true unless (t[:creatable] || t[:descendants].any?)
    end

    tree
  end

  def self.flatten_tree tree
    flat = []
    tree.each do |klass|
      klass[:filter] = ([klass[:klass]] + klass[:ancestors] + klass[:klass].descendants).map{ |x| I18n.t x.name }.join
      flat += [klass]
      flat += flatten_tree(klass[:descendants]) if klass[:descendants].any?
    end
    flat
  end
  
  # Dump ontology into file 
  def self.dump
    Rails.application.eager_load!
    c = "# Ontology Wissenschaftliche Sammlungen digital\n# #{Date.today}, Kontakt: martin.stricker@hu-berlin.de\n# This isn't Ruby code - don't try to execute it! ;-)\n"
    @@predicates.keys.sort.each do |key|
      klass = key.constantize
      # Individual
      c += "\n" + klass.name + " (de:'" + I18n.t(klass.name, default: "") + "') < " + klass.superclass.name + "\n"
      preds = predicates(klass)
      predicates(klass).keys.each do |k|
        # Predicate + :type
        c +=  "    #{k} (de:'" + I18n.t(k, default: "") + "') :#{preds[k][:type]}"
        # Cardinality
        c += ", cardinality: #{preds[k][:cardinality]}" if preds[k][:cardinality]
        # :objekt Range, inverse
        if preds[k][:type] == :objekt
          c += ", range: " + preds[k][:range].to_s.gsub(/\"/,'')
          c += ", inverse: #{preds[k][:inverse]}" if preds[k][:inverse]
        end
        c += "\n"
      end
    end
    path = Rails.root.join("log","ontology.rb").to_s
    File.write(path, c)
    "Saved to #{path}"
  end
  
  # Dump ontology into dot file
  def self.dot
    c = "digraph Maya {
  rankdir=\"TB\";
  overlap = false;
  splines = true;
  
  subgraph Classes {
    node [color=blue]
    edge [color=blue]\n"
    
    # Nodes
    Rails.application.eager_load!
    @@predicates.keys.sort.each do |key|
      klass = key.constantize
      if key != "Individual"
        c += "\t\t" + klass.name + " -> " + klass.superclass.name + "\n"
      end
    end
    c += "  }
  
  subgraph Properties {
    edge [color=red]\n"
    
    # Edges
    @@predicates.keys.sort.each do |key|
      klass = key.constantize
      preds = predicates(klass)
      predicates(klass,false).keys.each do |k|
        if preds[k][:type] == :objekt
          left = klass.name
          if preds[k][:range]
            range = ((preds[k][:range].class) == String) ? [preds[k][:range]] : preds[k][:range]
            range.each do |r|
              c += "\t\t" + left + " -> " + r + " [label=\"" + k + "\"]\n"
            end
          end
        end
      end
    end
    
    c += "\t}
}\n"
    path = Rails.root.join("log","graph.dot").to_s
    File.write(path, c)
    "Saved to #{path}"
  end
end
