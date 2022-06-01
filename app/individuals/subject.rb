# Data Model: SKOS Concept
class Subject < Concept
  property "is_subject", :objekt, range: "SciCollection", inverse: "subject"
  property "in_scheme", :objekt, range: "ConceptScheme", cardinality: 1, inverse: "has_concept", default: "Subject"
  property "broader", :objekt, range: "Subject", inverse: "narrower", hierarchical: true
  property "narrower", :objekt, range: "Subject", inverse: "broader", hierarchical: true

  property "small", :bool, cardinality: 1

  # Objekte bearbeiten dürfen nur Manager
  access_rule action: [:create, :edit, :delete], minimum_required_role: :manager
end
