require 'sparql/client'
class WikidataDereferencer < AuthorityDereferencer
  
  def self.dereferences? url
    if url.include? "wikidata.org/wiki"
      return true
    end
  end
  
  def self.dereference url
    
    wiki_id = url.split("/")[-1]
    
    endpoint = "https://query.wikidata.org/sparql"
    sparql = <<-SPARQL
    PREFIX entity: <http://www.wikidata.org/entity/>

    SELECT DISTINCT ?label ?description ?language
    WHERE {
      entity:#{wiki_id} rdfs:label ?label BIND( LANG(?label) AS ?language).
      entity:#{wiki_id} schema:description ?description BIND( LANG(?description) AS ?language). 
      FILTER ( ?language = "de"^^xsd:string || ?language = "en"^^xsd:string )
    }
    SPARQL

    client = SPARQL::Client.new(endpoint,
                                :method => :get)
    rows = client.query(sparql)
    
    return self.extract_data(rows)
  end
  
  def self.extract_data(rows)
    wikidata_hash = {description: {}, preferredName: {}}
    for row in rows
      row_hash = row.to_h
      lang = row_hash[:label].language.to_s
      label = row_hash[:label].value
      description = row_hash[:description].value
      
      wikidata_hash[:description][lang] = description
      wikidata_hash[:preferredName][lang] = label
    end
    return wikidata_hash
  end
  
end