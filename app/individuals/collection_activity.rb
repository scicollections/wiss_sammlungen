# Data Model: Collection Activity
class CollectionActivity < Activity
  property "activity_type", :objekt, range: "ActivityType", inverse: "is_activity_type", facet_link: "activitytype"
  property "used_collection", :objekt, range: "SciCollection", inverse: "used_in_activity"
  property "address", :objekt, range: "Address", inverse: "is_address"
  property "email", :email
  property "phone", :phone
  property "homepage", :objekt, range: "WebResource", inverse: "is_homepage"
  property "other_web_resource", :objekt, range: "WebResource", inverse: "is_other_web_resource"
  # CollectionActivity is linked to a DigitalCollection "directly" rather than
  # via a weak Individual (like SciCollection is via DigitalRepresentation)
  property "digital_collection", :objekt, range: "DigitalCollection", inverse: "collection_activity"

  access_rule action: [:edit, :delete], minimum_required_role: :manager
  access_rule action: [:create], minimum_required_role: :member

  # discover:
  category "activity"
  headline :label
  subheadline :activity_type
  description :used_collection, :inline_label
  description :involved_organisation, :inline_label
  description :involved_person
  separator :description, " - "
  facet :subject,       :used_collection, :subject, {include_hidden: [:alt_label, :label_en]}
  facet :genre,         :used_collection, :genre, {follow_hierarchy: true, include_hidden: [:alt_label, :label_en]}
  facet :collection,    :used_collection
  facet :person,        :involved_person
  facet :organisation,  :involved_organisation
  facet :organisationtype, :involved_organisation, :organisation_type
  facet :place,         :involved_organisation, :location
  facet :place,         :involved_organisation, :address, :location
  facet :activitytype,  :activity_type
  facet :state,         :involved_organisation, :address, :location, :state
  facet :collectiontype,:used_collection, :collection_type
  facet :collectionrole,:used_collection, :role
  facet :reproduction,  :used_collection, :digital_collection, :digital_collection ,:reproduction
  facet :livingbeing,   :used_collection, :living_being

  # @see Individual#class_display
  def class_from_predicate
    "activity_type"
  end

  # (see Individual#index_value)
  def index_value
    ca_type = activity_type.first ? class_display : "Aktivität"
    "#{ca_type}: #{label}"
  end
end
