# Implement our own SessionsController to be able to override the new action. This is to support an
# "Anmelden" link on the 403 error page. The usual method to store the location as implemented in
# the ApplicationController doesn't work on error pages, as the session isn't updated by the
# ErrorController. (If somebody figures out how to make it do that, this file is obsolete and can
# be removed.)
class SessionsController < Devise::SessionsController
  def new
    if (path = params[:redirect]).present?
      store_location_for(:user, path)
    end
    super
  end
end
