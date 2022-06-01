# Data Model: SKOS Concept
class ObjectGenre < Concept
  property "is_genre", :objekt, range: "SciCollection", inverse: "genre"
  property "in_scheme", :objekt, range: "ConceptScheme", cardinality: 1, inverse: "has_concept", default: "ObjectGenre"
  property "is_genre_for_holdinggroup", :objekt, range: "HoldingGroup", inverse: "genre"
  property "broader", :objekt, range: "ObjectGenre", inverse: "narrower", hierarchical: true
  property "narrower", :objekt, range: "ObjectGenre", inverse: "broader", hierarchical: true

  # Objekte bearbeiten dürfen nur Manager
  access_rule action: [:edit], minimum_required_role: :manager
  access_rule action: [:create, :delete], minimum_required_role: :admin

  # (see Individual.has_view?)
  def self.has_view?
    true
  end
  
  def self.classifying?
    true
  end
end
