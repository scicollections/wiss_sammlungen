# Data Model: SKOS Concept
class LivingBeing < Concept
  property "is_living_being", :objekt, range: "SciCollection", inverse: "living_being"
  property "in_scheme", :objekt, range: "ConceptScheme", cardinality: 1, inverse: "has_concept", default: "LivingBeing"
  property "broader", :objekt, range: "LivingBeing", inverse: "narrower", hierarchical: true
  property "narrower", :objekt, range: "LivingBeing", inverse: "broader", hierarchical: true

  # Objekte bearbeiten dürfen nur Manager
  access_rule action: [:create, :edit, :delete], minimum_required_role: :manager
end
