class GndDereferencer < AuthorityDereferencer
  
  def self.dereferences? url
    if url.include? "d-nb.info/gnd"
      return true
    end
  end
  
  def self.dereference url
    raise "NotAllowedUrl" unless self.dereferences?(url)
    
    gnd_id = url.split("/")[-1]
    url = "https://lobid.org/gnd/#{gnd_id}.json"
    
    uri = URI(url)
    response = Net::HTTP.get(uri)
    json_response = JSON.parse(response)
    
    preferredName = json_response.fetch("preferredName",nil)
    description = json_response.fetch("definition",[]).join(" ")
    
    return {
      preferredName: {
        "de": preferredName
      },
      description: {
        "de": description
      }
    }
  end
  
end