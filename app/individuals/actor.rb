# Data Model: Actor
class Actor < Individual
  property "address", :objekt, range: "Address", inverse: "is_address"
  property "email", :email
  property "phone", :phone
  property "homepage", :objekt, range: "WebResource", inverse: "is_homepage"
  property "other_web_resource", :objekt, range: "WebResource", inverse: "is_other_web_resource"
  property "description", :text, cardinality: 1
  property "related_actor", :objekt, range: ["Person", "Organisation"], inverse: "related_actor"

  # Objekte bearbeiten dürfen nur Admins, da Objekte über das Web-Interface eigentlich gar nicht
  # bearbeiten werden
  access_rule action: [:create, :edit, :delete], minimum_required_role: :admin
end
