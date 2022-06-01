# Data Model: SKOS Concept
class Concept < Individual
  property "in_scheme", :objekt, range: "ConceptScheme", cardinality: 1, inverse: "has_concept"
  property "broader", :objekt, range: "Concept", inverse: "narrower", hierarchical: true
  property "narrower", :objekt, range: "Concept", inverse: "broader", hierarchical: true
  property "selectable", :bool, cardinality: 1, default: true
  property "label_en", :string, cardinality: 1
  property "alt_label", :string
  property "change_note", :text, cardinality: 1
  property "special_status", :string, cardinality: 1, options: ["draft", "deprecated"]

  default_hierarchy_predicate "narrower"

  # Objekte bearbeiten dürfen nur Admins, da Objekte über das Web-Interface eigentlich gar nicht
  # bearbeiten werden
  access_rule action: [:create, :edit, :delete], minimum_required_role: :admin

  facet "english_label", :label_en

  # (see Individual.hierarchical?)
  def self.hierarchical?
    joins(:broader).any?
  end
end
