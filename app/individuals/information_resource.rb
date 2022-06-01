# Individual: Information Resource
class InformationResource < Individual
  property "dummy_property", :string

  # Objekte bearbeiten dürfen nur Admins, da Objekte über das Web-Interface eigentlich gar nicht
  # bearbeiten werden
  access_rule action: [:create, :edit, :delete], minimum_required_role: :admin
end
