source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.0.3'

# Use mysql as the database for Active Record
gem 'mysql2'

# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 3.2.0'

# See https://github.com/sstephenson/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'

# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'turbolinks'
# jQuery arbeitet wieder normal
# https://github.com/kossnocorp/jquery.turbolinks
gem 'jquery-turbolinks'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder'

group :development do
  gem 'scout_apm'
  gem 'bullet'
  # shows a rails console in browser when exception in development mode occurs
  gem 'web-console'
end

# Use ActiveModel has_secure_password
# gem 'bcrypt-ruby', '~> 3.1.2'

# Use unicorn as the app server
# gem 'unicorn'

# Use Capistrano for deployment
# gem 'capistrano', group: :development

# Use debugger
# include everywhere, since the debugger gem is used for formating error-output
# in the ErrorMailer
# gem 'debugger'
# Doesn't compile any more on MacOS Sierra

# Bootstrap & Less
gem "therubyracer"
# gem "less-rails"
# gem "twitter-bootstrap-rails"

# Bootstrap & Less 3
# Use forked repro to prevent deprecation warnings
gem 'less-rails-bootstrap', git: "https://github.com/paperculture/less-rails-bootstrap", ref: "88f7705"
gem "bootstrap-table-rails"

# RDF stuff
gem "linkeddata"

# Obfuscated Mail Links https://github.com/reed/actionview-encoded_mail_to
# encode: "hex"
gem "actionview-encoded_mail_to"

# debugger
gem "byebug"

# client-side charts
# http://chartkick.com
gem "chartkick"

# Elasticsearch
gem "elasticsearch"

# Session in DB speichern
gem "activerecord-session_store"

# Devise (User-Verwaltung)
gem "devise"

# Mail
# Dieses Gem ist eigentlich schon dabei, da actionmailer das benutzt. Aber das registriert keine
# globale "Mail"-Konstante, und die brauche ich aber in "config/application.rb", um die
# SMTP-Einstellungen festzulegen. Deswegen fordere ich das Mail-Gem hier noch einmal explizit.
gem "mail"

# Diffy, um die Diffs bei der Anzeige von Revisionen zu generieren.
gem "diffy"

# typeahead.js: autocomplete for quicksearch
gem "twitter-typeahead-rails"

# ICU Gem um alphabetisch zu sortieren
gem "ffi-icu", ">= 0.4"

# UTF-8 Cleaner: Verhindert encodingerrors die teilweise von Bots ausgelöst wurden
gem "utf8-cleaner"

# easy meta tags for seo
gem "meta-tags"

# lightweight templating engine
# https://github.com/slim-template/slim
gem "slim"

# spreadsheet generation
# See https://github.com/randym/axlsx
# Potentially https://github.com/straydogstudio/axlsx_rails 
gem "axlsx", "3.0.0.pre"

gem 'sprockets'
gem 'sass-rails', '~> 5.0', '>= 5.0.6'

# To recognize links in text
# https://github.com/tenderlove/rails_autolink
gem "rails_autolink"

# YARD (Ruby Documentation)
# See https://yardoc.org/
gem "yard"

# command line progress bar
# https://github.com/powerpak/tqdm-ruby
gem 'tqdm'

# SPARQL client gem
gem 'sparql-client', '~> 3.1'

# leaflet.js
gem 'leaflet-rails', '~> 1.7'
