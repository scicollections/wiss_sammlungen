# Represents a digital reproduction type.
class DigitalReproductionType < Concept
  property "is_reproduction_type", :objekt, range: "DigitalReproduction", inverse: "reproduction_type"
  property "in_scheme", :objekt, range: "ConceptScheme", cardinality: 1, inverse: "has_concept", default: "DigitalReproductionType"
  property "type_label", :string, cardinality: 1
  property "broader", :objekt, range: "DigitalReproductionType", inverse: "narrower", hierarchical: true
  property "narrower", :objekt, range: "DigitalReproductionType", inverse: "broader", hierarchical: true

  access_rule action: [:create, :edit, :delete], minimum_required_role: :admin
end
