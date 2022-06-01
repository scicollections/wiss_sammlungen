class Country < Place
  property "place_type", :objekt, range: "PlaceType", inverse: "is_place_type",
    cardinality: 1, default: "Country"
  property "is_country", :objekt, inverse: "country"
  property "same_as", :url, map_zoomlevel: 4

  # Objekte bearbeiten dürfen nur Manager
  access_rule action: [:create, :edit, :delete], minimum_required_role: :manager

  # @see Individual#class_display
  def class_from_predicate
    "place_type"
  end
end
