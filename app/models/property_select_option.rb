# PropertySelectOption

class PropertySelectOption < Property

  # Attribute Write value
  # :float
  def value=(value)
    self.data = value
  end

  # Attribute Read value
  # :float
  def value
    data
  end

  # Property Type
  # :float
  def property_type
    :select_option
  end
end
