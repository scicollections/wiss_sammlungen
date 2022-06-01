# PropertyUrl

class PropertyUrl < Property

  # Attribute Write value
  # :url
  def value=(value)
    url = value.to_s.strip
    unless uri? url
      url = "http://#{url}"
    end
    self.data = url
  end

  def uri? uri
    begin
      uri = URI.parse(uri)
      %w(http https ftp ftps).include?(uri.scheme)
    rescue
      true
    end
  end

  # Property Type
  # :url
  def property_type
    :url
  end

  def index_value
    if vocab = dereferences?(data)
      # use vocab name as index_value if possible
      return vocab.to_s
    
    # Strip everything except domain
    elsif data =~ /\A(?:http|https|ftp|ftps):\/\/((?:[a-z0-9\-]+\.)+[a-z]+)/i
      $1 # Return group 1 of last match
    else
      ""
    end
  end
  
  extend Dereferencable::ClassMethods
  include Dereferencable::InstanceMethods
  
  add_dereferencer :aat, AatDereferencer
  add_dereferencer :wikidata, WikidataDereferencer
  add_dereferencer :gnd, GndDereferencer
  add_dereferencer :geonames, GeonamesDereferencer
  
end
