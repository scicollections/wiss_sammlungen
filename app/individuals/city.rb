# Einfache Subklasse von Place um auf Klassenebene zwischen Stadt und z.B. Bundesland
# unterscheiden zu können.
class City < Place
  property "place_type", :objekt, range: "PlaceType", inverse: "is_place_type", cardinality: 1, default: "City"
  property "is_location", :objekt, inverse: "location"
  property "is_location_for_address", :objekt, range: "Address", inverse: "location"
  property "state", :objekt, range: "State", inverse: "is_state", cardinality: 1

  # Objekte bearbeiten dürfen nur Manager
  access_rule action: [:edit, :delete, :create], minimum_required_role: :manager
end
