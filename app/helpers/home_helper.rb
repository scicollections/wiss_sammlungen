module HomeHelper
  # Shorten a label to a given size and append "..." if any characters were removed.
  #
  # @param label [String] The label to shorten.
  # @param size [Integer] The new size.
  #
  # @return [String] The shortened label.
  def shorten_label label, size
    begin
      # check types of parameters
      if !label.is_a?(String)
        raise ArgumentError, ("parameter label is not a String")
      elsif !size.is_a?(Integer)
        raise ArgumentError, ("size is not an Integer")
      end
    rescue ArgumentError
      # only raise Exception in development mode
      raise if Rails.env.development?
      # in other environments return label or empty string instead
      if label.is_a?(String)
        return label
      else
        return ""
      end
    end

    if label.size > size
      label[0..size] + "..."
    else
      label
    end
  end

  # Choose the correct translation term, concerning the Indvidual's
  # gender-property and depending on the presence of these additional
  # translations in the following format in de.yml:
  #
  #     #{term.to_s}_#{gender.to_s}: translation
  #
  # @param term [#to_s] The term/predicate to be translated.
  # @param gender [#to_s] The gender referenced in de.yml.
  #
  # @return [String]
  def t_gender term, gender
    I18n.t [term, gender].join('_'), default: I18n.t(term)
  end
end
