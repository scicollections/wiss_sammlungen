# Creates spreadsheet reports
class Spreadsheet
  
  # Compile Spreadsheet
  def self.compile sheet="No Sheet Specified"
    ActiveRecord::Base.logger = nil
    if self.respond_to? (sheet.to_s.to_sym)
      list = self.send (sheet.to_s.to_sym)
      path = self.create_spreadsheet sheet.to_s, list
      return "Download <a href='#{path}'>#{sheet}.xlsx</a>"
    else
      return "This is not what you have been looking for. Ask the waves!"
    end
  end
  
  # uni, adress, postal code + city, list of sci collections
  def self.universitaeten
    list = []
    # Create list
    OrganisationType.find(2).sorted_properties(:is_organisation_type).each do |p|
      uni = p.value
      item = [uni.label]
      if(address = uni.address.first) 
        item[1] = address.value.safe_value("address_data")
        item[2] = address.value.safe_value("postal_code") + " " + (address.value.location.value.label if address.value.location).to_s
      end
      item[3] = uni.sorted_properties(:current_keeper).collect{|i|i.value.label}.join("; ")
      list << item
    end 
    list
  end
  
  # subject, list of sci collections, list of digital collections
  def self.fachgebiete
    list = []
    Subject.order("label").each do |f|
      item = [f.label]
      sc = []; dc = []; 
      (f.sorted_properties(:is_subject)).each do |c|
        classname = c.value.class.to_s
        if classname == "SciCollection"
          sc << c
        else
          dc << c
        end
      end
      item[1] = sc.collect{|i|i.value.inline_label}.join("; ")
      item[2] = dc.collect{|i|i.value.label}.join("; ")
      list << item
    end
    list
  end
  
  # object genre complex, list of sci collections, list of digital collections
  def self.objektgattungen_collections
    list = []
    ObjectGenreComplex.order("label").each do |f|
      item = [f.label]
      sc = []; dc = []; 
      (f.sorted_properties(:is_genre_complex)).each do |c|
        classname = c.value.class.to_s
        if classname == "SciCollection"
          sc << c
        else
          dc << c
        end
      end
      item[1] = sc.collect{|i|i.value.inline_label}.join("; ")
      item[2] = dc.collect{|i|i.value.label}.join("; ")
      list << item
    end
    list
  end
  
  # object genres, uris, broader
  def self.objektgattungen
    list = [["Top Term/Broader De", "De", "En", "URI", "Broader URI"]]
    ObjectGenre.default_hierarchy.items.each do |o|
      # Top Term or Broader Label
      if o.level == 0
        item = ["TT"]
        broader_uri = ""
      else
        item = [o.ancestors.last.label]
        broader_uri = "http://portal.wissenschaftliche-sammlungen.de/ObjectGenre/" + o.ancestors.last.id.to_s
      end
      # Label
      item << o.indi.label
      # English Label
      item << o.indi&.label_en_value
      # URI
      item << "http://portal.wissenschaftliche-sammlungen.de/ObjectGenre/" + o.indi.id.to_s
      # Broader URI
      item << broader_uri
      list << item
    end
    list
  end
  
  # Mailadressen von Kunstsammlungen & Ansprechpartner*innen
  def self.kunstsammlungen
    list = []
    # Create Query
    search = Searcher.new
    sconf = {
      scope: :manager,
      cat_filter: [:collection],
      facet_filter: {subject: ["Kunstgeschichte", "Kunst", "Christliche Kunst"]},
      size: 1000   
    }
    search.configure sconf
    search.execute
    search.results.each do |c|
      col = SciCollection.find(c[:id])
      # Mailadressen der Sammlungen
      unless col.email.empty?
        list << [
          c[:id], 
          col.label, 
          col.safe_value("location"), 
          "Sammlung",
          "",
          "",
          (col.safe_values("email")).first
        ]
      end 
      # Mailadressen der Ansprechpartner*innen
      unless col.curator.empty?
        col.curator.each do |curatorship_property|
          unless (curatorship_property.value).curator.nil?
            unless (curatorship_property.value).curator.value.email.empty?
              list << [
                c[:id], 
                col.label, 
                col.safe_value("location"), 
                "Ansprechpartner*in",
                (curatorship_property.value).curator.value.label,
                (curatorship_property.value).curator.value.title,
                ((curatorship_property.value).curator.value.safe_values("email")).first
              ]
            end
          end
        end
      end
    end
    list
  end
  
  # Mailadressen von Human Remains-Sammlungen & Ansprechpartner*innen
  def self.humanremains
    list = []
    # Create Query
    Property.where("data = 'provenance_status_human_remains'").each do |p|
      col = SciCollection.find(p[:subject_id])
      # Mailadressen der Sammlungen
      unless col.email.empty?
        list << [
          "https://portal.wissenschaftliche-sammlungen.de/SciCollection/" + col.id.to_s, 
          col.label, 
          col.safe_value("location"), 
          "Sammlung",
          "",
          "",
          (col.safe_values("email")).first
        ]
      end 
      # Mailadressen der Ansprechpartner*innen
      unless col.curator.empty?
        col.curator.each do |curatorship_property|
          unless (curatorship_property.value).curator.nil?
            unless (curatorship_property.value).curator.value.email.empty?
              list << [
                "https://portal.wissenschaftliche-sammlungen.de/SciCollection/" + col.id.to_s, 
                col.label, 
                col.safe_value("location"), 
                "Ansprechpartner*in",
                (curatorship_property.value).curator.value.label,
                (curatorship_property.value).curator.value.mail_salutation,
                ((curatorship_property.value).curator.value.safe_values("email")).first
              ]
            end
          end
        end
      end
    end
    list
  end
  
  # Sammlungen der Humboldt-Universitaet
  def self.hu
    list = [["Name", 
              "URL (Portal)", 
              "Ansprechpartner*innen",
              "Adresse",
              "Öffnungszeiten",
              "Fachgebiet(e)",
              "Homepage(s)", 
              "Link zu Sammlungsportal HU",
              "Onlinesammlungen",
              "Zahl der Objekte",
              "Objektgattung(en)",
              "Dokumentierte Sammlungsgeschichte",
              "Verwendung in der akademischen Lehre",
              "Benutzungsordnung",
              "Sammlungskonzept",
              "Budget",
              "Provenienzabklärung"]]
    Organisation.find(657).sorted_properties(:current_keeper).tqdm.each do |cp|
      c = cp.value
      p c.label
      
      curatorships = c.curator_value
      curator_names = c.curator_value.collect{|cs| cs.curator_value.label}.join ", "
      homepage_urls = c.homepage_value.collect{|h| h.url_value}.join ", "
      hu_samm = c.collection_portal_value.collect{|h| h.url_value}.select{|url| url.include?("sammlungen.hu-berlin.de")}.first
      obj_count = c.sum_holding_figures[:objects][:figure].to_s
      obj_count = (obj_count == "0") ? "" : obj_count
      obj_count_ca = c.sum_holding_figures[:objects][:ca] ? "ca." : ""
      genres = c.holding_figures.collect{|hsh| hsh[:genre]}
      genres += c.safe_values "genre_complex"
      genres = genres.uniq.join ", "
      address = c.safe_value "address"
      opening_hours = c.safe_value "opening_hours"
      subjects = (c.safe_values "subject").uniq.join ", "
      documented_history = c.safe_values("has_documented_history").collect{|s| I18n.t(s)}.join ", "
      academic_teaching = c.safe_values("academic_teaching").collect{|s| I18n.t(s)}.join ", "
      provenance = c.safe_values("provenance_status").collect{|s| I18n.t(s)}.join ", "
      
      usage_regulation = c.has_usage_regulation_value 
      collection_concept = c.has_collection_concept_value
      budget = c.has_budget_value
      usage_regulation = I18n.t usage_regulation if usage_regulation
      collection_concept = I18n.t collection_concept if collection_concept
      budget = I18n.t budget if budget
      
      digital_collections = []
      c.digital_collection_value.each do |dc|
        if url = dc.landing_page_value
          digital_collections << url
        else
          digital_collections << dc.digital_collection_value.access_value
        end
      end
      digital_collections = digital_collections.join ", "
      
      data = [c.label, "https://portal.wissenschaftliche-sammlungen.de/SciCollection/"+c.id.to_s]
      data << curator_names
      data << address
      data << opening_hours
      data << subjects
      data << homepage_urls
      data << hu_samm
      data << digital_collections
      data << "#{obj_count_ca} #{obj_count}"
      data << genres
      data << documented_history
      data << academic_teaching
      data << usage_regulation
      data << collection_concept
      data << budget
      data << provenance
      
      
      list << data
    end
    p list
  end
  
  def self.bua_contacts
    bunis = Organisation.where(id: [657,345,651,294])
    bcolls = SciCollection.all.select{|coll| (coll.has_current_keeper_value & bunis).any? }
    list = [["Name", 
              "Email", 
              "Telefon",
              "Universität",
              "Sammlung(en)"]]
    bcurators = bcolls.collect{|coll| coll.curator_value.collect{|cur| cur.curator_value}}.flatten.uniq
    
    bcurators.tqdm.each do |curator|
      data = [curator.label, curator.safe_value("email"),curator.safe_value("phone"),curator.safe_value("organisation")]
      colls = curator.curated_collection_value.collect{|cur| cur.curated_collection_value}
      colls.each do |coll|
        data << coll.label
        data << coll.purl
      end
      list << data
    end
    list
  end
  
  def self.bua_genres
    bunis = Organisation.where(id: [657,345,651,294])
    bcolls = SciCollection.all.select{|coll| (coll.has_current_keeper_value & bunis).any? }
    list = [["Objektgattung", 
              "Uni", 
              "Sammlung",
              "Link zur Sammlung"]]
              
    bgenres = bcolls.collect{|coll| [coll, coll.genre_complex_value.collect{|gc| gc.genre_value}]}
    hierarchy_items = ObjectGenre.default_hierarchy.items
    
    bgenres.tqdm.each do |coll, genres|
      # infer broader terms
      new_genres = genres
      genres.each do |value|
        item = hierarchy_items.find{|item| item.indi == value}
        ancestors = item.ancestors
        new_genres += ancestors
      end
      new_genres.uniq!
      
      new_genres.each do |genre|
        list << [genre.label, coll.safe_value("has_current_keeper"), coll.label, coll.purl]
      end
    end
    list
  end
  
  # Create Spreadsheet file and return path
  def self.create_spreadsheet name, list
    # Store in Excel file
    Axlsx::Package.new do |p|
      # Wrap text if there are newlines
      wrap = p.workbook.styles.add_style alignment: {wrap_text: true}
      # Fix bug on MS Excel 2011 on Mac OS X: Display newline (CR/LF) correctly 
      p.workbook.use_shared_strings = true
      p.workbook.add_worksheet(:name => name.capitalize) do |sheet|
        list.each do |row|
          sheet.add_row row, style: wrap
        end
        # You guessed it: MS Excel 2011 on Mac OS X chokes on not defined column widths. :-(
        sheet.column_widths 50, 50, 50, 50, 50, 50, 50, 50
      end
      p.serialize(Rails.root.join("public","spreadsheets", "#{name}.xlsx"))
    end
    "/spreadsheets/#{name}.xlsx"
  end 
end
