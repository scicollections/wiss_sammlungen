# PropertyInteger
class PropertyInteger < Property
  
  validates_numericality_of :data_int, less_than: 2**31
  validates_numericality_of :data_int, greater_than: -2**31

  # Attribute Write value
  # :integer
  def value=(value)
    # parse numerical input
    value = value.gsub /[^-0-9]/, ""
    self.data_int = value.to_i
  end

  # Attribute Read value
  # :integer
  def value
    data_int
  end

  # (see Property#property_type)
  def property_type
    :integer
  end
end
