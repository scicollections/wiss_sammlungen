# Represents a cached API response.
#
# @example
#   a = ApiCache.create
#   => throws ActiveRecord::StatementInvalid (da Felder nicht NULL sein dürfen)
#
# @example
#   a = ApiCache.create(api: "Lobid", authority_file: "GND", authority_id: "salkdj", data_json: "{}")
#   => OK
#
# @example
#   a = ApiCache.create(api: "Lobid", authority_file: "GND", authority_id: "salkdj", data_json: "{}")
#   => throws ActiveRecord::RecordNotUnique
class ApiCache < ActiveRecord::Base
  self.table_name = "api_cache"

  # @return [Hash] A parsed version of the cached API response data.
  def data
    @data ||= JSON.parse(data_json)
  end

  # Update the API response (but don't write to the DB).
  #
  # @param data_hash [Hash] The new API response data.
  def data= data_hash
    @data = data_hash
    self.data_json = data_hash.to_json
    # Änderung wurde noch nicht in die Datenbank geschrieben!
  end
end
