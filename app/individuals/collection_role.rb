# Data Model: Collection Role
class CollectionRole < Concept
  property "is_role", :objekt, range: "SciCollection", inverse: "role"
  property "in_scheme", :objekt, range: "ConceptScheme", cardinality: 1, inverse: "has_concept", default: "CollectionRole"
  property "broader", :objekt, range: "CollectionRole", inverse: "narrower", hierarchical: true
  property "narrower", :objekt, range: "CollectionRole", inverse: "broader", hierarchical: true
  
  # Objekte bearbeiten dürfen nur Manager
  access_rule action: [:create, :edit, :delete], minimum_required_role: :manager
end
