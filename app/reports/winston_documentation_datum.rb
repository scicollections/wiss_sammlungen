# Datum to store documentation status dependent on provenance information.
class WinstonDocumentationDatum < ReportDatum
  belongs_to :report

  has_field :provenance_status, :string1
  has_field :has_documented_history_collection, :int1
  has_field :has_documented_history_objects, :int2
  has_field :has_documented_history_none, :int3
end
