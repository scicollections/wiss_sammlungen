require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)

module Maya
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.enforce_available_locales = true
    config.i18n.default_locale = :de

    config.mailhost = {
      "development" => "localhost:3000",
      "production" => "portal.wissenschaftliche-sammlungen.de"
    }
    
    config.action_mailer.default_url_options = { host: config.mailhost[Rails.env]}

    APP_CONFIG = YAML.load_file(Rails.root.join("config", "config.yml"))[Rails.env] rescue {}
    email_settings = APP_CONFIG["action_mailer"]

    if email_settings
      # Für ActionMailer, genutzt zum Beispiel bei Passwort-Zurücksetzen-Mails
      email_settings.each do |key, value|
        config.action_mailer[key] = value.is_a?(Hash) ? value.symbolize_keys : value
      end

      # Für Mail, genutzt zum Beispiel beim Einladen von Benutzern
      Mail.defaults do
        delivery_method :smtp, email_settings["smtp_settings"].symbolize_keys
      end
    end

    # add own dateformat to Date Hash
    Date::DATE_FORMATS[:ger_date] = '%d.%m.%Y'
    Time::DATE_FORMATS[:ger_datetime] = '%d.%m.%Y %H:%M'
    
    config.paths.add 'app/survey', eager_load: true
    config.assets.paths << Rails.root.join('vendor', 'assets', 'fonts')  
    config.assets.precompile << /\.(?:svg|eot|woff|ttf)$/
    
  end
end
