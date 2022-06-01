# PropertyEmail
class PropertyEmail < Property
  validate :valid_encoding
  
  # ensure valid format for email addresses in database, strict == raise exception
  validates :data, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i,
    message: "Ungültige E-Mail-Adresse." }

  # (see Property#property_type)
  def property_type
    :email
  end
  
  private 
  def valid_encoding
    # email address must be ascii encodable
    begin
      data.encode("ascii")
    rescue Encoding::UndefinedConversionError => e
      errors.add(:data, :invalid, message: "Ungültige Kodierung/Sonderzeichen in der E-Mail-Adresse")
    end
  end
end
