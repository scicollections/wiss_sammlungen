xml.instruct! :xml, :version => "1.0", :encoding=> "utf-8"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title @feedtitle
    xml.description "Kürzliche Änderungen"
    xml.link @feedabout

    @items.each do |item|
      xml.item do
        xml.title item[:title]
        xml.description item[:content]
        xml.pubDate item[:updated].rfc2822
        xml.link item[:link]
        xml.guid item[:uuid]
      end
    end
  end
end