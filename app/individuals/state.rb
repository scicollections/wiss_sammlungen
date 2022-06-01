# Individual: Location
class State < Place
  property "place_type", :objekt, range: "PlaceType", inverse: "is_place_type",
    cardinality: 1, default: "State"
  property "is_state", :objekt, inverse: "state"
  property "same_as", :url, map_zoomlevel: 6

  # Objekte bearbeiten dürfen nur Manager
  access_rule action: [:create, :edit, :delete], minimum_required_role: :manager

  # @see Individual#class_display
  def class_from_predicate
    "place_type"
  end
end
