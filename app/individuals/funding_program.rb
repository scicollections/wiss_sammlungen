# Data Model: Funding Program
class FundingProgram < Activity
  property "current_deadline", :date, cardinality: 1
  property "procedures_and_rules", :text, cardinality: 1
  property "address", :objekt, range: "Address", inverse: "is_address"
  property "email", :email
  property "phone", :phone
  property "homepage", :objekt, range: "WebResource", inverse: "is_homepage"
  property "other_web_resource", :objekt, range: "WebResource", inverse: "is_other_web_resource"
  property "funding_area", :objekt, range: "ActivityType", inverse: "is_funding_area"
  
  # Objekte bearbeiten dürfen nur Admins
  access_rule action: [:create, :edit, :delete], minimum_required_role: :manager

  # discover:
  category "activity"
  headline :label
  subheadline "Förderprogramm"
  description :involved_organisation, :inline_label
  description :involved_person
  separator :description, " - "
  facet :person,        :involved_person
  facet :organisation,  :involved_organisation
  facet :organisationtype, :involved_organisation, :organisation_type
  facet :place,         :involved_organisation, :location
  facet :place,         :involved_organisation, :address, :location
  facet :activitytype,  "Förderprogramm"
end
