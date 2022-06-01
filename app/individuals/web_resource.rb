# Individual: Web Resource
class WebResource < InformationResource
  property "name", :string, cardinality: 1, affects_label: true
  property "url", :url, cardinality: 1, affects_label: true
  property "is_homepage", :objekt, inverse: "homepage", cardinality: 1, is_owner: true
  property "is_collection_portal", :objekt, inverse: "collection_portal", cardinality: 1,
    is_owner: true
  property "is_other_web_resource", :objekt, inverse: "other_web_resource", cardinality: 1,
    is_owner: true
  property "is_internal_database_for", :objekt, inverse: "has_database_internal", cardinality: 1,
      is_owner: true
  # Objekte
  property "shows", :objekt, inverse: "is_shown_at", cardinality: 1, is_owner: true
  # Universitäten
  property "is_collections_order_url", :objekt, inverse: "collections_order_url", cardinality: 1, is_owner: true

  # (see Individual.weak?)
  def self.weak?
    true
  end

  private

  def set_labels
    tname = self.safe_value "name"
    turl = self.safe_value "url"
    unless tname.size == 0
      self.label = tname
    else
      self.label = turl.size > 80 ? turl[0, 80] + "..." : turl
    end
    self.inline_label = label
  end
end
