# Represents a {State} (Bundesland) in a Winston report.
class WinstonState < ReportDatum
  belongs_to :report

  has_many :universities,
    -> (this) { where(report_id: this.report_id) },
    class_name: "WinstonUniversity",
    primary_key: :string2, # WinstonState.admin1
    foreign_key: :string4 # WinstonUniversity.state_admin1

  has_field :name, :string1
  has_field :admin1, :string2
  has_field :university_count, :int1
  has_field :collection_count, :int2
  has_field :active_collection_count, :int3
  has_field :collection_coordination_count, :int4
  has_field :collection_policy_count, :int5
  has_field :webportal_count, :int6
  has_field :maya_id, :int7
  has_field :digitized_collection_count, :int8
  has_field :object_portal_count, :int9

  # Order by name and ignore "kein Bundesland zugeordnet" by default
  default_scope -> { where.not(string2: nil).order(:string1) }

  before_create { self.legacy_name = "bundesland" }
end
