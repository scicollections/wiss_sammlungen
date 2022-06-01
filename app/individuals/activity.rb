# Data Model: Activity
class Activity < Event
  property "involved_person", :objekt, range: "Person", inverse: "activity"
  property "involved_organisation", :objekt, range: "Organisation", inverse: "activity"
  property "description", :text, cardinality: 1
  property "related_activity", :objekt, range: "Activity", inverse: "related_activity"

  # Objekte bearbeiten dürfen nur Admins
  access_rule action: [:create, :edit, :delete], minimum_required_role: :admin

  # (see Individual#automatically_editable_by)
  #
  # All Persons connected via `involved_person` may edit this activity.
  def automatically_editable_by
    involved_person_value
  end
end
