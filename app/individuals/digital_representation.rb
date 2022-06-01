# A weak individual that connects SciCollections with DigitalCollections in order
# to model DigitalCollections that aggregate the digital representations of several
# SciCollections.
#
# The sole purpose of this weak Individual is to store an additional URL (deep link
# to SciCollection representation in the DigitalCollection) to the URL in the
# DigitalCollection which is the address of the (possibly aggregate) DigitalCollection.
class DigitalRepresentation < Individual
  property "sci_collection", :objekt, range: "SciCollection", inverse: "digital_collection",
    cardinality: 1, is_owner: true, fill_on_create: true, affects_label: true
  property "digital_collection", :objekt, range: "DigitalCollection", inverse: "sci_collection", cardinality: 1,
    is_owner: true, fill_on_create: true, affects_label: true
  property "landing_page", :url, cardinality: 1

  # (see Individual.weak?)
  def self.weak?
    true
  end

  # (see Individual.has_view?)
  def self.has_view?
    false
  end

  private

  def set_labels
    # these labels are barely visible in the UI, only in left column of edit-modals
    label = "#{self.safe_value "digital_collection"} (Digitale Sammlung) für #{self.safe_value 'sci_collection'}"
    self.label = label
    self.inline_label = label
  end
end
