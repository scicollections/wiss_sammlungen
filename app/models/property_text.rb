# PropertyString

class PropertyText < Property

  # Attribute Write value
  # :text
  def value=(value)
    self.data_text = value.to_s.strip
  end

  # Attribute Read value
  # :text
  def value
    data_text
  end

  # Property Type
  # :text
  def property_type
    :text
  end
end
