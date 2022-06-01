# Datum to store documentation status for a subject OR col type.
class WinstonProvenanceDocumentation < ReportDatum
  belongs_to :report

  has_field :has_documented_history, :string1
  has_field :subject, :int1
  has_field :collection_type, :int2
  has_field :collection_count, :int3
  
end
