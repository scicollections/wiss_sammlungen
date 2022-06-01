class ImageQuality < Concept
  property "is_image_quality", :objekt, range: "DigitalReproduction", inverse: "image_quality"
  property "in_scheme", :objekt, range: "ConceptScheme", cardinality: 1, inverse: "has_concept", default: "ImageQuality"
  property "broader", :objekt, range: "ImageQuality", inverse: "narrower", hierarchical: true
  property "narrower", :objekt, range: "ImageQuality", inverse: "broader", hierarchical: true

  property "sort_value", :integer, cardinality: 1

  access_rule action: [:create, :edit, :delete], minimum_required_role: :admin
end
