# Represents a digital reproduction.
class DigitalReproduction < Individual
  # the fill_on_create options is neccessary here! it tells glass that for a newly created DigitalReproduction to immediately show it's edit input elements (located in glass/edit/_digital_reproduction.html.erb)
  property "reproduction_type", :objekt, range: "DigitalReproductionType", inverse: "is_reproduction_type", cardinality: 1, fill_on_create: true, affects_label: true

  property "digital_collection", :objekt, range: "DigitalCollection", inverse: "reproduction", cardinality: 1, is_owner: true
  property "comment", :text, cardinality: 1
  property "image_quality", :objekt, range: "ImageQuality", inverse: "is_image_quality", cardinality: 1, affects_label: true
  property "image_width", :integer, cardinality: 1, default: nil
  property "image_height", :integer, cardinality: 1, default: nil

  access_rule action: [:create, :edit, :delete], minimum_required_role: :admin

  # (see Individual.weak?)
  def self.weak?
    true
  end

  private

  def set_labels
    self.inline_label = self.safe_value("reproduction_type")
    self.label = self.inline_label
  end
end
