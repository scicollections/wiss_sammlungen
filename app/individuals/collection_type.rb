# Data Model: SKOS Concept
class CollectionType < Concept
  property "is_collection_type", :objekt, range: "SciCollection", inverse: "collection_type"
  property "in_scheme", :objekt, range: "ConceptScheme", cardinality: 1, inverse: "has_concept", default: "CollectionType"
  property "broader", :objekt, range: "CollectionType", inverse: "narrower", hierarchical: true
  property "narrower", :objekt, range: "CollectionType", inverse: "broader", hierarchical: true

  # Objekte bearbeiten dürfen nur Manager
  access_rule action: [:create, :edit, :delete], minimum_required_role: :manager
end
