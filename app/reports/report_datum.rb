# Represents an archived version of an {Individual} or some kind of aggregated data.
class ReportDatum < ApplicationRecord
  belongs_to :report

  before_save :truncate_strings

  # Establish connections between descriptive field names and database column names.
  #
  # @param field_name [Symbol] The descriptive field name.
  # @param column_name [Symbol] The column_name (:int1, :string8, etc.).
  def self.has_field field_name, column_name
    raise "Can't use '#{field_name}'" if column_names.include?(field_name.to_s)

    define_method(field_name) { send(column_name) }
    define_method("#{field_name}=") { |value| send("#{column_name}=", value) }
  end

  # Get the associated Maya individual.
  #
  # @note Will not cache an "Individual not found" result.
  #
  # @return [Individual] The associated Maya individual, if it exists.
  # @return [nil] Otherwise.
  #
  # @raise [MethodNotFound] If used on a ReportDatum that didn't define "maya_id".
  def indi
    @indi ||= Individual.find_by(id: maya_id)
  end

  # @return [String] The (first) URL associated to the associated Maya individual.
  # @return [nil] Otherwise.
  #
  # @raise [MethodNotFound] If the individual doesn't have a "homepage" property.
  def url
    # homepage is an individual which possibly has a label, in consequence
    # the url cannot be simply ge accessed via uni.safe_value "homepage" (which
    # will return the label of the homepage Individual) but must be extracted explicitly
    @url ||=
      begin
        if indi && indi.homepage_value.any?
          indi.homepage_value.first.safe_value("url")
        else
          ""
        end
      end
  end

  private

  # Truncate strings to avoid persistence errors caused by too long strings.
  def truncate_strings
    self.attributes.each_pair do |key, value|
      # generate names of string fields string1, string2, ..., string15
      columns = (1..15).collect { |i| "string"+i.to_s }
      if columns.include? key
        if value.present?
          self[key] = value.truncate(255)
        end
      end
    end
  end
end
