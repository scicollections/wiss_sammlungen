# Data Model: SKOS Concept Scheme
class ConceptScheme < Individual
  property "has_concept", :objekt, range: "Concept", inverse: "in_scheme"
  property "selectables", :bool, cardinality: 1, default: false
  property "hierarchical", :bool, cardinality: 1, default: false

  # Objekte bearbeiten dürfen nur Manager
  access_rule action: [:create, :edit, :delete], minimum_required_role: :manager
end
