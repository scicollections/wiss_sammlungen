xml.instruct! :xml, :version => "1.0", :encoding=> "utf-8"
xml.feed xmlns: "http://www.w3.org/2005/Atom" do
  xml.author do
    xml.name @feedauthor
  end
  
  xml.title @feedtitle
  xml.id "urn:uuid:60a76c80-d399-11d9-b93C-0003939e0af6"
  xml.updated @feedupdate
  
  
  @items.each do |item|
    xml.entry do
      xml.title item[:title]
      xml.content type: "html" do 
        xml.div item[:content]
      end
      xml.updated item[:updated].rfc3339
      xml.link item[:link]
      xml.id item[:uuid]
    end
  end
  
end