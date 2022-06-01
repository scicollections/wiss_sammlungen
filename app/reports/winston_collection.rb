# Represents a {SciCollection} in a Winston report.
class WinstonCollection < ReportDatum
  belongs_to :report

  has_many :digital_representations,
    -> (this) { where(report_id: this.report_id) },
    class_name: "WinstonDigitalRepresentation",
    primary_key: :int1, # WinstonCollection.maya_id
    foreign_key: :int1 # WinstonDigitalRepresentation.sci_collection_id

  has_field :maya_id, :int1
  has_field :uni_id, :int2
  has_field :name, :string1
  has_field :admin1, :string2
  has_field :is_active, :bool1
  has_field :has_contact, :bool2
  has_field :has_digital_collection, :bool3

  before_create { self.legacy_name = "sammlung" }
end
