module ErrorHelper
  # @return [String] An obfuscated HTML link to support email address.
  def support_mail
    address = Maya::Application::APP_CONFIG["support_mail"]
    mail_to address, address, encode: "hex"
  end
end
