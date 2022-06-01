# Data Model: Activity Type
class ActivityType < Concept
  property "is_activity_type", :objekt, range: "CollectionActivity", inverse: "activity_type"
  property "is_funding_area", :objekt, range: "FundingProgram", inverse: "funding_area"
  property "in_scheme", :objekt, range: "ConceptScheme", cardinality: 1, inverse: "has_concept", default: "ActivityType"
  property "broader", :objekt, range: "ActivityType", inverse: "narrower", hierarchical: true
  property "narrower", :objekt, range: "ActivityType", inverse: "broader", hierarchical: true

  # Objekte bearbeiten dürfen nur Manager
  access_rule action: [:create, :edit, :delete], minimum_required_role: :manager
end
