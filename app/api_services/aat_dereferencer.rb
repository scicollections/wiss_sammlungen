class AatDereferencer < AuthorityDereferencer
  
  def self.dereferences? url
    if url.include? "vocab.getty.edu"
      return true
    end
    return false
  end
  
  def self.dereference url
    raise "NotAllowedUrl" unless self.dereferences?(url)
    
    aat_id = url.split("/")[-1]
    url = "http://vocab.getty.edu/aat/#{aat_id}.json"
    
    uri = URI(url)
    
    req = Net::HTTP::Get.new(uri)
    req['Accept'] = "*/*"
    
    new_location = Net::HTTP.start(uri.hostname, uri.port) do |http|
        resp = http.request(req)
        resp.header["location"]
    end
    
    new_uri = URI(new_location)
    new_req = Net::HTTP::Get.new(new_uri)
    new_req['Accept'] = "*/*"
    
    resp = Net::HTTP.start(new_uri.hostname, new_uri.port) do |http|
        http.request(new_req)
    end
    json_response = JSON.parse(resp.body)
    
    return {
      preferredName: self.aat_extract_labels(json_response),
      description: self.aat_extract_notes(json_response)
    }
  end
  
  
  def self.aat_extract_notes aat_hash
    pred = "http://www.w3.org/2004/02/skos/core#note"
    pred2 = "http://www.w3.org/1999/02/22-rdf-syntax-ns#value"
    refs = aat_hash["results"]["bindings"].select{|stmtHash| stmtHash["Predicate"]["value"] == pred}
            .collect{|stmtHash| stmtHash.dig("Object","value")}
    
    notes = aat_hash["results"]["bindings"].select{|stmtHash| refs.include?(stmtHash["Subject"]["value"]) and 
                    stmtHash["Predicate"]["value"] == pred2 and 
                    stmtHash["Object"]["type"] == "literal"}
            .collect{|stmtHash| [stmtHash["Object"].fetch("xml:lang"), stmtHash.dig("Object","value")]}
            
    notes = Hash[notes] 
    notes
  end
  
  def self.aat_extract_labels aat_hash
    pred = "http://www.w3.org/2000/01/rdf-schema#label"
    pred2 = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

    labels = aat_hash["results"]["bindings"].select{|stmtHash| stmtHash["Predicate"]["value"] == pred and
                                                  stmtHash["Object"]["type"] == "literal"}
            .collect{|stmtHash| [stmtHash["Object"].fetch("xml:lang"), stmtHash["Object"]["value"]]}
            
    labels = Hash[labels] 
    labels
  end
  
end