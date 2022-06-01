# Class to specify quantities with or without uncertainty
class Quantity < Individual
  property "figure", :integer, cardinality: 1, affects_label: true
  property "circa", :bool, cardinality: 1, default: false, affects_label: true, bool_delete_on_false: true
  property "is_object_quantity", :objekt, range: "HoldingGroup", cardinality: 1, inverse: "object_quantity", is_owner: true
  property "is_indexed_quantity", :objekt, range: "HoldingGroup", cardinality: 1, inverse: "indexed_quantity", is_owner: true
  property "is_digitized_quantity", :objekt, range: "HoldingGroup", cardinality: 1, inverse: "digitized_quantity", is_owner: true
  property "is_online_available_quantity", :objekt, range: "HoldingGroup", cardinality: 1, inverse: "online_available_quantity", is_owner: true

  def self.weak?
    true
  end
  
  def self.complex_property?
    true
    
  end

  private

  def set_labels
    str = "#{circa_value ? "ca. " : ""}#{ActiveSupport::NumberHelper::number_to_delimited(figure_value, locale: "de")}"

    
    self.label = str
    self.inline_label = str
  end
end
