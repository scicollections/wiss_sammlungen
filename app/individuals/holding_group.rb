class HoldingGroup < Individual
  property "genre", :objekt, range: "ObjectGenre", cardinality: 1, inverse: "is_genre_for_holdinggroup", fill_on_create: true, affects_label: true
  property "object_quantity", :objekt, range: "Quantity", cardinality: 1, inverse: "is_object_quantity"
  property "indexed_quantity", :objekt, range: "Quantity", cardinality: 1, inverse: "is_indexed_quantity"
  property "digitized_quantity", :objekt, range: "Quantity", cardinality: 1, inverse: "is_digitized_quantity"
  property "online_available_quantity", :objekt, range: "Quantity", cardinality: 1, inverse: "is_online_available_quantity"
  property "is_holdinggroup", :objekt, range: "SciCollection", inverse: "has_holdinggroup", is_owner: true, cardinality: 1, fill_on_create: true, affects_label: true
  def self.weak?
    true
    # Alternative: eine Klasse-Methode "subsists_on", dem als Argumente die Predicates
    # gegeben werden, die Revisions receiven. Individuals, wo diese Liste nicht leer ist,
    # werden dann als weak interpretiert.
  end

  private

  def set_labels
    
    str = "Bestand: #{genre_value.label if genre}"
    
    self.label = str
    self.inline_label = str
  end
end
