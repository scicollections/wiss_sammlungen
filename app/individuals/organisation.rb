# Data Model: Organisation
class Organisation < Actor
  property "organisation_type", :objekt, range: "OrganisationType", inverse: "is_organisation_type"
  property "location", :objekt, range: "City", inverse: "is_location", cardinality: 1, facet_link: "place"
  property "country", :objekt, range: "Country", inverse: "is_country", cardinality: 1
  property "current_keeper", :objekt, range: "SciCollection", inverse: "has_current_keeper"
  property "associated_collection", :objekt, range: "SciCollection", inverse: "associated_organisation"
  property "activity", :objekt, range: "Activity", inverse: "involved_organisation"
  property "person", :objekt, range: "Person", inverse: "organisation"
  property "collection_publications", :text, cardinality: 1
  property "collections_order", :bool, cardinality: 1
  property "collections_order_url", :objekt, range: "WebResource", inverse: "is_collections_order_url", cardinality: 1
  property "collection_portal", :objekt, range: "WebResource", inverse: "is_collection_portal", cardinality: 1
  property "object_portal", :objekt, range: "DigitalCollection", inverse: "is_object_portal", cardinality: 1
  property "description", :text, cardinality: 1
  property "state", :objekt, range: "State", inverse: "is_state", cardinality: 1
  property "same_as", :url, map_zoomlevel: 14
  

  access_rule action: [:edit, :delete], minimum_required_role: :manager
  access_rule action: [:create], minimum_required_role: :member

  # discover:
  category "actor"
  headline :self
  subheadline :location
  description :current_keeper
  description :activity
  separator :description, " - "
  facet :subject,       :current_keeper, :subject, {include_hidden: [:alt_label, :label_en]}
  facet :genre,         :current_keeper, :genre, {follow_hierarchy: true, include_hidden: [:alt_label, :label_en]}
  facet :collection,    :current_keeper
  facet :livingbeing,   :current_keeper, :living_being
  facet :person,        :person
  facet :organisation,  :self
  facet :place,         :address, :location
  facet :place,         :location
  facet :organisationtype, :organisation_type
  facet :state,         :address, :location, :state
  facet :reproduction,  :current_keeper, :digital_collection, :digital_collection ,:reproduction
  facet :collectiontype,    :current_keeper, :collection_type
  facet :collectiontype,    :current_keeper, :role
  facet :activitytype,      :activity, :activity_type
  facet :vocab,             :same_as

  # @see Individual#class_display
  def class_from_predicate
    "organisation_type"
  end
  

  # @return [Array<Person>] The Persons that are allowed to edit this Organisation implicitly
  #   (unsorted).
  def automatically_editable_by
    # all Persons connected via person may edit this Organisation if it is no
    # University (of the Arts/Music) or Higher Education Instituion
    if not allows_automatic_editing?
      []
    else
      person_value
    end
  end
  
  # @return [Boolean] whether this organisation allows to be automatically
  # edited by associated people. 
  # For now: only universities (of the arts/music) and higher education institutions 
  # do NOT allow automatic editing.
  def allows_automatic_editing?
    return !(organisation_type_value & [OrganisationType.university,
      OrganisationType.university_of_the_arts_or_music,
      OrganisationType.higher_education_institution]).present?
  end
  
  # Get all Organisation of Type University of The Arts or Music, University or 
  # Higher Education Institution.
  # @return [Array<Organisation>] 
  def self.generic_institutions_of_higher_education
    arr = OrganisationType.university.is_organisation_type_value +
          OrganisationType.higher_education_institution.is_organisation_type_value +
          OrganisationType.university_of_the_arts_or_music.is_organisation_type_value
    return arr.uniq
  end

  # Get all funding organisations.
  #
  # @return [Array<Organisation>]
  def self.funding_organisations
    OrganisationType.funding_organisation.is_organisation_type_value
  end

  # Get all universities.
  #
  # @return [Array<Organisation>]
  def self.universities
    OrganisationType.university.is_organisation_type_value
  end
end
