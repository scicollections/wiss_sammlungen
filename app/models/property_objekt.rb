# PropertyObjekt
class PropertyObjekt < Property
  belongs_to :objekt, inverse_of: :is_objekt, class_name: "Individual"

  validate :check_for_illegal_objekt_id

  # Attribute Write value
  # :objekt
  def value=(value)
    self.objekt = value
  end

  # Attribute Read value
  # :objekt
  def value
    objekt
  end

  # Attribute Read value for Sort
  def sort_value
    if(value.respond_to?(:sort_value))
      value.sort_value
    else
      value.inline_label
    end
  end

  # @return The value's index value.
  def index_value
    value.index_value
  end

  # Property Type
  # :objekt
  def property_type
    :objekt
  end

  # (see Property.inverse)
  def inverse
    if @inverse && objekt_id == @inverse.subject_id && subject_id == @inverse.objekt_id
      return @inverse
    end

    @inverse = Property.where(subject_id: objekt_id,
                              predicate: subject.inverse_of(predicate),
                              objekt_id: subject_id).first
  end

  private

  def check_for_illegal_objekt_id
    subject.illegal_objekt_ids_with_reasons(predicate)[objekt_id].each do |reason|
      errors.add(:base, reason)
    end
  end
end
