# Represents a version of the Kennzahlen for a specific point in time.
class Report < ApplicationRecord
  has_many :report_datum, dependent: :delete_all

  has_many :states, class_name: "WinstonState"
  has_many :universities, class_name: "WinstonUniversity"
  has_many :digital_collections, class_name: "WinstonDigitalCollection"

  # TODO Eventually rename association "report_datum" to "report_data".
  def report_data
    report_datum
  end

  # @return The total number of collections.
  #
  # @note "collection_count" is correct, not "collections_count", see:
  #   https://english.stackexchange.com/questions/349475/singular-or-plural-noun-preceeding-count
  def collection_count
    @collection_count ||=
      if rd = report_data.find_by(legacy_name: "absolut_sammlungen")
        rd.int1
      end
  end

  # @return The total number of universities.
  def university_count
    @university_count ||=
      if rd = report_data.find_by(legacy_name: "absolut_universitaeten")
        rd.int1
      end
  end

  # @return The global collection type counts.
  def collection_type_counts
    @collection_type_counts ||=
      begin
        rds = report_data.where(legacy_name: "anteile_sammlungsart", int3: id)
        rds.each_with_object({}) do |type, hash|
          hash[type.string1] = type.int2 unless type.string1 == "keine Angabe"
        end
      end
  end

  # @return The counts for active and inactive collections.
  def collection_status_counts
    @collection_status_counts ||=
      begin
        hash = report_data.where(type: "WinstonCollection").group(:bool1).count
        # Rename keys
        hash["keine Angabe"] = hash.delete(nil)
        hash["aktiv"] = hash.delete(true)
        hash["nicht aktiv"] = hash.delete(false)
        hash
      end
  end
end
