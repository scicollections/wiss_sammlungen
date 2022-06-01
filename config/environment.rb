# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
Maya::Application.initialize!

# At this point the Rails application will be fully loaded.
# The following code performs initialisation checks that need the application
# to be loaded.

# ensure that the database contains the necessary ontology-constants
begin
  ActiveRecord::Base.establish_connection # Establishes connection
  ActiveRecord::Base.connection
  Ontology.ensure_ontology_constants
rescue
  puts "No database connection found. Ontology constants will be created later."
end