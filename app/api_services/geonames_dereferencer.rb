class GeonamesDereferencer < AuthorityDereferencer
  
  def self.dereferences? url
    if url.include? "geonames.org"
      return true
    end
  end
  
  # dereference and locate using wikidata
  def self.dereference url
    
    geonames_id = url.split("/")[-1]
    
    endpoint = "https://query.wikidata.org/sparql"
    sparql = <<-SPARQL

    SELECT DISTINCT ?item ?itemLabel ?lat ?lon ?globe ?description ?language
    WHERE {
      ?item wdt:P1566 "#{geonames_id}";
        wdt:P625 ?coord.
      ?item p:P625 [
               psv:P625 [
                 wikibase:geoLatitude ?lat ;
                 wikibase:geoLongitude ?lon ;
                 wikibase:geoGlobe ?globe ;
               ] ;
               ps:P625 ?coordinates
             ].
      ?item schema:description ?description BIND( LANG(?description) AS ?language).
      ?item rdfs:label ?itemLabel BIND( LANG(?itemLabel) AS ?language).
      SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
      FILTER ( ?language = "de"^^xsd:string || ?language = "en"^^xsd:string )
    }
    SPARQL

    client = SPARQL::Client.new(endpoint,
                                :method => :get)
    rows = client.query(sparql)
    
    return self.extract_data(rows)
  end
  
  def self.extract_data(rows)
    wikidata_hash = {lat: nil, lon: nil, preferredName: {}, description: {}, wikidata: nil}
    for row in rows
      row_hash = row.to_h
      lang = row_hash[:itemLabel].language.to_s
      label = row_hash[:itemLabel].value
      description = row_hash[:description].value
      
      wikidata_hash[:description][lang] = description
      wikidata_hash[:preferredName][lang] = label
    end
    first_row = rows.first.to_h
    wikidata_hash[:wikidata] = first_row[:item].value if first_row[:item]
    wikidata_hash[:lat] = first_row[:lat].value if first_row[:lat]
    wikidata_hash[:lon] = first_row[:lon].value if first_row[:lon]
    return wikidata_hash
  end
  
end

