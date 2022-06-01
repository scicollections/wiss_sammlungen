# PropertyString

class PropertyString < Property
  validates :data, length: { maximum: 500 }

  # (see Property#property_type)
  def property_type
    :string
  end
end
