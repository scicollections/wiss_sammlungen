Maya::Application.routes.draw do
 # Home
  root 'home#index'
  
  # Docs
  get '/docs', to: redirect("/docs/index.html")


  # Discover
  post 'discover', to: 'discover#json'#, constraints: lambda { |req| req.format == :json }
  get 'discover/', to: 'discover#index'
  get 'discover/:categories', to: 'discover#index'
  get 'discover/:categories/:key', to: 'discover#facets'
  get 'navigation/:hit', to: 'discover#navigation'
  get 'opensearch.xml', to: 'discover#opensearch'

  # Intere Suche
  #get 'search/', to: 'search#index'
  #get 'search/:klass', to: 'search#index'
  get 'search(/:filter)', to: 'search#index'

  # Quicksearch
  get 'quicksearch', to: 'discover#quicksearch'

  # Edit
  get 'edit', to: 'edit#edit_modal'
  get 'new', to: 'edit#new_modal'
  get 'edit/range', to: 'edit#range'
  get 'edit/property', to: 'edit#property'
  get 'edit/weak_individual_form', to: 'edit#weak_individual_form'

  # Update
  post 'update/individual', to: 'update#create_individual'
  put 'update/individual', to: 'update#update_individual'
  delete 'update/individual', to: 'update#delete_individual'
  get 'validate/property', to: 'update#validate_property'
  post 'update/property', to: 'update#create_property'
  put 'update/property', to: 'update#update_property'
  delete 'update/property', to: 'update#delete_property'
  post 'update/table_row', to: "update#new_table_row"

  # Meta
  get 'info', to: 'home#info'
  get 'credits', to: 'home#credits'
  get 'lizenzen', to: 'home#licenses'

  # Revisions & Relations
  get 'revisions/feed.rss', to: 'home#rss', defaults: {format: 'rss'} 
  get 'revisions/feed.atom', to: 'home#rss', format: 'atom' 
  get 'revisions/feed(.:format)', to: 'home#rss', defaults: {format: 'rss'} 
  get 'revisions', to: 'home#revisions'
  get 'relations', to: 'individual#relations'


  # API
  get 'api/fibonacci/individual', to: 'api#fibonacci_individual'
  get 'api/fibonacci/search', to: 'api#fibonacci_search'
  get 'api/fibonacci/outofthebox', to: 'api#fibonacci_outofthebox'
  get 'api/isus/collections/:id', to: 'api#isus_collection'

  # Winston
  get 'kennzahlen', to: 'winston#global'
  get 'kennzahlen/index', to: redirect('/kennzahlen')
  get 'kennzahlen/bundeslaender', to: "winston#states"
  get 'kennzahlen/digitale-sammlungen', to: "winston#digital_collections"
  get 'kennzahlen/about', to: "winston#about"
  get 'kennzahlen/universitaet/:university_id', to:'winston#university'
  get 'kennzahlen/uni_coll_data', to:"winston#uni_coll_data"
  get 'kennzahlen/no_report_yet', to: "winston#no_report_yet"
  get 'kennzahlen/fluctuation', to: "winston#fluctuation"
  get 'kennzahlen/progress', to: "winston#progress"
  get 'kennzahlen/teaching', to: "winston#teaching"
  get 'kennzahlen/collectionhistory', to: "winston#collectionhistory"
  get 'kennzahlen/provenance', to: "winston#provenance"
  get 'kennzahlen/digitization', to: "winston#digital_collections"
  get 'kennzahlen/budget', to: "winston#budget"
  get 'kennzahlen/usage_regulation', to: "winston#usage_regulation"
  get 'kennzahlen/collection_concept', to: "winston#collection_concept"
  
  
  # Legacy Winston URL redirects
  get 'kennzahlen/:report_id/global', to: redirect('/kennzahlen')
  get 'kennzahlen/:report_id/states', to: redirect('/kennzahlen/bundeslaender')
  get 'kennzahlen/:report_id/university/:university_id', to: redirect('/kennzahlen/universitaet/%{university_id}')
  get 'kennzahlen/faecher', to: "winston#subjects"
  # Survey
  get 'survey/home', to: "survey#home"
  get 'survey/dashboard/(:slug)', to: "survey#dashboard"
  post 'survey/event', to: 'survey#create_event'
  post 'survey/multiple_invite', to: 'survey#multiple_invite'
  get 'survey/usereventslist', to: 'survey#user_events_list'
  get 'survey/join/:survey_token', to: 'survey#join'
  put 'survey/transform_account', to: 'survey#transform_account'
  get 'survey/inviteform', to: 'survey#inviteform'
  get 'survey/clarify', to: "survey#clarify"
  get 'survey/inactive', to: "survey#inactive"
  post 'survey/clarify', to: "survey#process_clarify"
  get 'survey/form/:individual_id', to: "survey#show_form"
  get 'survey/checkdata', to: "survey#check_data"
  get 'survey/changed_predicates', to: "survey#changed_predicates"
  get 'survey/stats', to: "survey#statistics"

  # User
  # "controllers"-Zusatz, damit unser angepasster RegistrationsController berücksichtigt wird.
  devise_for :users, class_name: 'User', controllers: {
    registrations: "registrations",
    sessions: "sessions",
  }
  get 'users/new', to: 'users#new'
  get 'users/show_recent_invite', to: 'users#show_recent_invite'
  post 'users/send_invite', to: 'users#send_invite'
  get 'users/home', to: 'users#home'
  get 'users/notes', to: 'users#notes'
  get 'users/privacy', to: 'users#privacy'
  get 'users/quickguide', to: 'users#quickguide'
  get 'users/invite_status', to: 'users#invite_status'
  post 'users/request_action', to: 'users#request_action'
  get 'users/:id', to: 'users#show'
  get 'users/home/api', to: 'users#api_index'
  get 'join/:token', to: 'users#join'
  put 'join/:token', to: 'users#update_by_join_token'
  
  post '*path', :to => 'error#unknown_post_route'

  ### No Routes Beyond This Point (ask Martin why)
  
  # partial with dereferenced data for a property 
  get ':individual/:id/dereferenced_data/:property_id', to: 'individual#dereferenced_data'

  # Revisions for a single individual
  get ':individual/:individual_id/revisions', to: 'home#revisions'

  # "Default" Route to get to individuals
  get ':individual/:id(/:sec_id)', to: 'individual#show', defaults: {sec_id: 0}

end
