# Data Model: SKOS Concept
class PlaceType < Concept
  property "is_place_type", :objekt, range: "Place", inverse: "place_type"
  property "in_scheme", :objekt, range: "ConceptScheme", cardinality: 1, inverse: "has_concept", default: "PlaceType"
  property "broader", :objekt, range: "PlaceType", inverse: "narrower", hierarchical: true
  property "narrower", :objekt, range: "PlaceType", inverse: "broader", hierarchical: true

  # Objekte bearbeiten dürfen nur Manager
  access_rule action: [:create, :edit, :delete], minimum_required_role: :manager
end
