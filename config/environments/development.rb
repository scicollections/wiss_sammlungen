Maya::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Marius: Habe Eager-Load eingeschaltet, damit bekannt ist, welche Kinder Individual
  # hat. So kann man beim Erstellen von Individuals alle vorhandenen Klassen anzeigen.
  # Zweiter Anwendungsfall: Bei der Range von "can_edit" ist "Individual" angebenen,
  # und für die Query braucht man dann das Wissen um die Subklassen.
  # Es würde reichen, nur die Dateien in "app/individuals" eager zu loaden. Wenn es dafür
  # eine gute Methode gibt, dann könnten wir dazu wechseln, um ein paar hundert Startup-
  # Millisekunden zu sparen.
  #
  # "Dir[Rails.root.join("app/individuals/*.rb")].each { |file| require file }" ist nicht gut,
  # da damit die "reload!"-Methode in der Rails-Console aus irgendeinem Grund nicht mehr
  # funktioniert, das heißt Änderungen an Individual-Klassen werden dann nicht gereloadet.
  # Wenn jemand dieses Problem lösen kann, dann können wir die Require-Methode benutzen und
  # Eager-Load wieder ausstellen.
  config.eager_load = true
  # (pre)loading all campaign files
  # https://www.sapandiwakar.in/eager-load-rails-classes-during-development/
  config.eager_load_paths += Dir['app/survey/*.rb']
  ActiveSupport::Reloader.to_prepare do  
    Dir["app/survey/*.rb"].each { |f| require_dependency("#{Dir.pwd}/#{f}") }
  end  

  # Show full error reports and disable caching.
  # Julian: Standardmäßige Stacktrace-Fehlerseiten deaktivieren um die Fehlerseiten des
  # ErrorControllers sichtbar zu machen (true: Stacktrace, false: ErrorController)
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # 404/500 error handling
  config.exceptions_app = ->(env) { ErrorController.action(:show).call(env) }
  # for testing HTTP error handling in development mode set config.consider_all_requests_local = false
  # this disables the Stacktrace-Errorpages that are shown in development environment per default
  # config.consider_all_requests_local = false # - treats all requests as production (for testing)
  
  config.hosts << "localhost"
  
end
