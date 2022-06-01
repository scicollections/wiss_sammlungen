# PropertyPhone
class PropertyPhone < Property
  # TODO ensure valid format for phone numbers
  validates :data, format: { with: /\A[0-9+\ ()]*\z/i,
    message: "Ungültige Telefonnummer." }

  # (see Property.property_type)
  def property_type
    :phone
  end
end
