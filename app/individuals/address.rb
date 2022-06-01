# Individual: Address
class Address < Place
  property "place_type", :objekt, range: "PlaceType", inverse: "is_place_type",
    cardinality: 1, default: "Address"
  property "is_address", :objekt, cardinality: 1, inverse: "address", is_owner: true
  property "address_data", :text, cardinality: 1, affects_label: true
  property "postal_code", :string, cardinality: 1, affects_label: true,
    validate: :postal_code_format
  property "location", :objekt, range: "City", inverse: "is_location_for_address", cardinality: 1,
    affects_label: true

  # (see Individual.weak?)
  def self.weak?
    true
  end

  # Validate the postal code.
  #
  # @param property [Property] The property to be validated.
  def postal_code_format property
    unless property.value =~ /\A\d{4,5}\z/
      property.errors.add(:base, "Ungültige Postleitzahl.")
    end
  end

  private

  def set_labels
    self.label = [
      (self.safe_value "address_data").gsub(/\r/,"").gsub(/\n/,", "),
      [(self.safe_value "postal_code"), (self.safe_value "location")].reject { |e| e.length == 0 }.join(" ")
    ].reject { |e| e.length == 0 }.join(", ")
    self.inline_label = label
  end
end
