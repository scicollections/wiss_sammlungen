# Represents a {DigitalCollection} in a Winston report.
class WinstonDigitalCollection < ReportDatum
  belongs_to :report

  # It's important to restrict query to the same report, because we join by *Maya* ID, which is not
  # unique to this *Winston*DigitalCollection.
  has_many :digital_representations,
    -> (this) { where(report_id: this.report_id) },
    class_name: "WinstonDigitalRepresentation",
    primary_key: :int1, # WinstonDigitalCollection.maya_id
    foreign_key: :int2 # WinstonDigitalRepresentation.digital_collection_id

  has_field :maya_id, :int1

  # Using "name" instead of "label" because of pre-existing practice in Winston.
  has_field :name, :string1
end
