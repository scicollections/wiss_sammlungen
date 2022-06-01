# PropertyFloat
class PropertyFloat < Property

  # Attribute Write value
  # :float
  def value=(value)
    self.data_float = value.to_f
  end

  # Attribute Read value
  # :float
  def value
    data_float
  end

  # (see Property#property_type)
  def property_type
    :float
  end
end
