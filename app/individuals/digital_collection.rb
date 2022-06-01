# Represents a digital collection.
class DigitalCollection < Individual
  # SciCollections are linked indirectly to DigitalCollections, via a weak
  # Individual DigitalRepresentation, which can be used to store a deep link
  # into the WebResource specified here as "access"
  property "sci_collection", :objekt, range: "DigitalRepresentation", inverse: "digital_collection"
  # CollectionActivitys are linked directly to DigitalCollections
  property "collection_activity", :objekt, range: "CollectionActivity", inverse: "digital_collection"
  property "access", :url, cardinality: 1

  property "is_object_portal", :objekt, range: "Organisation", inverse: "object_portal", cardinality: 1

  property "reproduction", :objekt, range: "DigitalReproduction", inverse: "digital_collection"

  # discover:
  category "digital"
  headline :self
  subheadline :access
  description :sci_collection, :sci_collection, :inline_label
  description :collection_activity, :inline_label
  separator :description, " - "
  facet :subject,       :sci_collection, :sci_collection, :subject
  facet :genre,         :sci_collection, :sci_collection, :genre, {follow_hierarchy: true, include_hidden: [:alt_label, :label_en]}
  facet :livingbeing,   :sci_collection, :sci_collection, :living_being
  facet :collection,    :sci_collection, :sci_collection
  facet :person,        :sci_collection, :sci_collection, :curator, :curator
  facet :person,        :collection_activity, :involved_person
  facet :organisation,  :sci_collection, :sci_collection, :has_current_keeper
  facet :organisation,  :collection_activity, :involved_organisation
  facet :organisationtype, :sci_collection, :sci_collection, :has_current_keeper,
    :organisation_type
  facet :organisationtype, :sci_collection, :sci_collection, :special_form
  facet :organisationtype, :collection_activity, :involved_organisation, :organisation_type
  facet :place,         :sci_collection, :sci_collection, :location
  facet :place,         :sci_collection, :sci_collection, :address, :location
  facet :reproduction,  :reproduction
  facet :collectiontype,:sci_collection, :sci_collection, :collection_type
  facet :collectionrole,:sci_collection, :sci_collection, :role
  facet :state,         :sci_collection, :sci_collection, :has_current_keeper, :address, :location, :state
  facet :state,         :sci_collection, :sci_collection, :address, :location, :state
  facet :activitytype,  :sci_collection, :sci_collection, :used_in_activity, :activity_type
end
