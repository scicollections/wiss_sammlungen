module I18nHelper
  # Overrides the default translation helper method that returns an error if no translation
  # is found; in this case the desired behaviour is to return the original string
  # instead and raises an exception that is processed by the ErrorController.
  #
  # @see http://stackoverflow.com/a/23138291/1870317
  def translate(key, options={})
    super(key, options.merge(raise: true))
  rescue I18n::MissingTranslationData => e
    # in case no translation for key is found: report error and simply return untranslated key
    # TODO report error to ErrorController
    logger.error "Missing translation for key \'" + key.to_s + "\""
    key
  end
  alias :t :translate
end
