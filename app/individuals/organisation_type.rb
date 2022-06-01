# Data Model: SKOS Concept
class OrganisationType < Concept
  property "is_organisation_type", :objekt, range: "Organisation", inverse: "organisation_type"
  property "in_scheme", :objekt, range: "ConceptScheme", cardinality: 1, inverse: "has_concept", default: "OrganisationType"
  property "broader", :objekt, range: "OrganisationType", inverse: "narrower", hierarchical: true
  property "narrower", :objekt, range: "OrganisationType", inverse: "broader", hierarchical: true

  property "special_form_of", :objekt, range: "SciCollection", inverse: "special_form"

  # Objekte bearbeiten dürfen nur Manager
  access_rule action: [:create, :edit, :delete], minimum_required_role: :manager

  # Get "University" ontology constant.
  def self.university
    # NB Can't memoize this because then ActiveRecord won't rerun associated queries
    find_by(descriptive_id: "University")
  end

  # Get "FundingOrganisation" ontology constant.
  def self.funding_organisation
    find_by(descriptive_id: "FundingOrganisation")
  end
  
  # Get "Higher Education Institution" ontology constant.
  def self.higher_education_institution
    find_by(descriptive_id: "HigherEducationInstitution")
  end
  
  # Get "University Of The Arts Or Music" ontology constant.
  def self.university_of_the_arts_or_music
    find_by(descriptive_id: "UniversityOfTheArtsOrMusic")
  end
end
