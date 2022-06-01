# Represents an {Organisation} of type "Universität" in a Winston report.
class WinstonUniversity < ReportDatum
  belongs_to :report
  has_many :collections, class_name: "WinstonCollection", foreign_key: :int2
  has_many :collection_coordinations, class_name: "WinstonCollectionCoordination",
    foreign_key: :int2

  belongs_to :state,
    -> (this) { where(report_id: this.report_id) },
    class_name: "WinstonState",
    primary_key: :string2, # WinstonState.admin1
    foreign_key: :string4 # WinstonUniversity.state_admin1

  has_field :name, :string1
  has_field :maya_id, :int1
  has_field :place, :string2
  has_field :state_admin1, :string4
  has_field :coll_count, :int2
  has_field :active_coll_share, :int3
  has_field :admin_coll_share, :int4
  has_field :digital_coll_share, :int5
  has_field :has_coll_coord, :bool1
  has_field :has_coll_policy, :bool2
  has_field :has_coll_website, :bool3
  has_field :has_object_portal, :bool4

  default_scope -> { order(:string1) }

  before_create { self.legacy_name = "universitaet" }

  # @raise [NoMethodError] If there are no coordinates for this university.
  def lat
    WinstonHelper::UNI_COORDS[maya_id]["lat"]
  end

  # @raise [NoMethodError] If there are no coordinates for this university.
  def lon
    WinstonHelper::UNI_COORDS[maya_id]["lon"]
  end

  # @return [Hash] The distribution of the different collection types of this university.
  def coll_type_shares
    @coll_type_shares ||= report
      .report_data
      .where(legacy_name: "anteile_sammlungsart", int3: id)
      .sort_by(&:string1) # Using "sort_by" and not "order" to get "keine Angabe" at last position
      .each_with_object({}) { |rd, result| result[rd.string1] = rd.int2 }
  end

  # @return [List] The subjects in the different collections at this university.
  def coll_subjects
    @coll_subjects ||= report
      .report_data
      .where(legacy_name: "anteile_fachgebiet", int3: id)
      .sort_by(&:string1) # Using "sort_by" and not "order" to get "keine Angabe" at last position
      .inject({}) {|hsh, rd| hsh[rd.string1 ] = rd.int2; hsh}
  end

  # @return [String] The descriptive text from `config/winston_university_texts.yml` for this
  #   university, if one exists.
  # @return [nil] Otherwise.
  def description
    if file = YAML.load_file('config/winston_university_texts.yml')
      file.each do |k,v|
        if k == maya_id
          return v
        end
      end
    end
    nil
  end

  # @param report [Report] The report.
  # @param maya_id [Interger] The university's maya ID.
  #
  # @return [WinstonUniversity] The university from the given report that corresponds to an
  #   {Organisation} with the given maya ID.
  def self.find_by_maya_id(report, maya_id)
    raise ArgumentError, "Ungültiges Report Objekt übergeben." unless Report === report
    report.universities.find_by!(int1: maya_id)
  end
end
