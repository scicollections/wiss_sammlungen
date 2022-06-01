# Represents a {Person} associated with an {Organisation} of type "Sammlungskoordination" in a
# Winston report.
class WinstonCoordinationContact < ReportDatum
  belongs_to :report

  has_field :maya_id, :int1
  has_field :coord_id, :int2 # Winston ID
  has_field :name, :string1

  before_create { self.legacy_name = "person" }
end
