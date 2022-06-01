# this class is designated to be the central
# module/class for sending mails out of maya
#
# For now, it's a simple helper class 
class PostOffice
  FROM = Maya::Application::APP_CONFIG["support_mail"]
  
  
  # This method provides a single point in the app, where mail addresses can be filtered. By using this method when sending an email, the developer prevents accidently sending emails to real persons.
  # This class returns a mail address depending on current rails environment settings. 
  # If the application runs in acceptance/production mode and in config.yml is 'send_emails: true' set, 
  # this method will return the very same email that has been given as a paremeter. Otherwise it will 
  # return the current 'support_mail' address.
  #
  # @param email [String] a real mail address, e.g. for a person to be invited
  # @return [String] an email address. Depending on rails env settings it is the address given as parameter or the 'support_mail' address  
  def to_address email
    if Rails.env.production? || Rails.env.acceptance?
      if Maya::Application::APP_CONFIG["send_emails"]
        return email
      end
    end
    return FROM
  end
  
  
  
  
  
end