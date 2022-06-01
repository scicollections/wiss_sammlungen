# Represents the association of a {SciCollection} with a {DigitalCollection} in a Winston report.
class WinstonDigitalRepresentation < ReportDatum
  belongs_to :report

  has_field :sci_collection_id, :int1 # is a Maya ID
  has_field :digital_collection_id, :int2 # is a Maya ID
end
