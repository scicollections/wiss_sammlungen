require 'net/http'
require 'json'

class AuthorityDereferencer
  
  def self.dereferences? url
    raise NotImplementedError
  end
  
end