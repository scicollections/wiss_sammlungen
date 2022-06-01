class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_action :application_wide_data, :check_format
  before_action :store_location, unless: :devise_controller?

  # Set the page title.
  #
  # @param title [String] The page title.
  # @param replace [Boolean] Whether to "replace" the title, i.e. *not* append the generic title.
  def page_title title=nil, replace: false
    if title && title.to_s.length > 0
      @page_title = "#{title}"
      unless replace
        @page_title += " • #{(t "maya_title")}"
      end
    end
  end

  # @return [User] The current user.
  def current_user
    # "super" geht zu der current_user-Methode von Devise. Die gibt nil zurück, wenn
    # man nicht eingeloggt ist. In diesem Fall wollen wir aber den anonymous_user bekommen.
    super || User.anonymous_user
  end

  # Fehler, die der Benutzer sehen darf
  class UserError < StandardError; end
  
  def http_auth
    authenticate_with_http_token do |token, _|
      if user = User.find_by(api_key: token)
        sign_in :user, user
      else
        sign_in :user, User.anonymous_user
      end
    end
  end
  
  rescue_from ActionView::MissingTemplate do |exception|
    raise ErrorController::MissingTemplate
  end

  private

  # Checks the requested format. Fallback to :html for unsupported formats.
  def check_format
    unless [:html, :json, :rss, :atom].include? request.format.to_sym
      request.format = :html
    end
  end

  def application_wide_data
    @page_title = t "maya_title"

    # reset active tab in user navigation
    # the active one is set in the respective Controller
    if (cur = current_user).present?
      # raise exception if the current_user is public or has no associated Person
      # because this association is assumed to be present throughout the application
      unless cur.public? || cur.admin? || cur.person.present?
        raise ErrorController::UserWithoutPerson, "current_user #{cur}:#{cur.id} has no associated Person"
      end
      @user_menu_tab_self_active = false
      @user_menu_tab_home_active = false
      @user_menu_tab_search_active = false
      @user_menu_tab_revisions_active = false
      @user_menu_tab_settings_active = false

      @menu_tab_discover_active = false
      @menu_tab_kennzahlen_active = false
    end
  end

  # store location to redirect after login
  def store_location
    # store last url - this is needed for post-login redirect to whatever the user last visited.
    return unless request.get?
    if !request.xhr?  #do not store locations for xhr requests
      store_location_for(:user, request.url)
    end
  end

  # redirect after user login
  # see https://github.com/plataformatec/devise/wiki/How-To:-Redirect-back-to-current-page-after-sign-in,-sign-out,-sign-up,-update
  # and http://www.rubydoc.info/github/plataformatec/devise/Devise/Controllers/StoreLocation
  def after_sign_in_path_for(resource)
    stored_location_for(:user) || root_path
  end
end
