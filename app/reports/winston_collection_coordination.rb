# Represents an {Organisation} of type "Sammlungskoordination" in a Winston report.
class WinstonCollectionCoordination < ReportDatum
  belongs_to :report
  has_many :contacts, class_name: "WinstonCoordinationContact", foreign_key: :int2

  has_field :name, :string1
  has_field :maya_id, :int1
  has_field :uni_id, :int2 # winston ID

  before_create { self.legacy_name = "sammlungskoordination" }

  # @return [Array<WinstonCoordinationContact>]
  def public_contacts
    @public_contacts ||= contacts.find_all { |c| (p = Person.find_by(id: c.maya_id)) && p.public? }
  end
end
