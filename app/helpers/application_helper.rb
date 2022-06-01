module ApplicationHelper
  # Obfuscate a string.
  #
  # @see http://www.truespire.com/2009/05/30/obfuscating-email-addresses-in-ruby-on-rails
  # @param str [String] The string.
  # @return [String] The obfuscated string.
  def encode_str str
    return nil if str.nil? # Don't bother if the parameter is nil.
    lower = ('a'..'z').to_a
    upper = ('A'..'Z').to_a
    str.split('').map { |char|
      output = lower.index(char) + 97 if lower.include?(char)
      output = upper.index(char) + 65 if upper.include?(char)
      output = 32 if char == " "
      output = 58 if char == ":"
      output = 64 if char == "@"
      output ? "&##{output};" : char
    }.join
  end

  # @return [String] The production URL in the form `https://host/path`.
  # @note The host is defined in application.rb
  # @note Don't hard-code "https://portal.wissenschaftliche-sammlungen", use this method instead!
  # @param path [String] The path to be appended to the production host.
  def production_url path=nil
    path = "/#{path}".sub(/^\/\/*/,"/") if path # ensure exactly one leading slash
    "https://#{Maya::Application.config.mailhost['production']}#{path}"
  end
end
