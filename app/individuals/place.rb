# Individual: Place
class Place < Individual
  property "place_type", :objekt, range: "PlaceType", inverse: "is_place_type", cardinality: 1

  # Objekte bearbeiten dürfen nur Manager
  access_rule action: [:create, :edit, :delete], minimum_required_role: :admin

  # @see Individual#class_display
  def class_from_predicate
    "place_type"
  end
end
