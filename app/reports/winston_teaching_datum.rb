# Datum to store documentation status dependent on provenance information.
class WinstonDocumentationDatum < ReportDatum
  belongs_to :report

  has_field :subject, :int1
  has_field :collection_type, :int2
  has_field :academic_teaching_basic, :int3
  has_field :academic_teaching_interdisciplinary, :int4
  has_field :no_academic_teaching, :int5

end
