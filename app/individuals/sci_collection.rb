# Data Model: Wissenschaftliche Sammlung
class SciCollection < Individual
  # Sammlung
  property "location", :objekt, range: "City", inverse: "is_location", cardinality: 1,
    affects_label: true, facet_link: "place"
  property "has_current_keeper", :objekt, range: "Organisation", inverse: "current_keeper"
  property "associated_organisation", :objekt, range: "Organisation", inverse: "associated_collection"
  property "collection_type", :objekt, range: "CollectionType", inverse: "is_collection_type", cardinality: 1, facet_link: "collectiontype"
  property "role", :objekt, range: "CollectionRole", inverse: "is_role", facet_link: "collectionrole"
  property "active_collection", :bool, cardinality: 1
  property "special_form", :objekt, range: "OrganisationType", inverse: "special_form_of", facet_link: "organisationtype"
  property "part_of", :objekt, range: "SciCollection", inverse: "has_part", hierarchical: true
  property "has_part", :objekt, range: "SciCollection", inverse: "part_of", hierarchical: true
  # TODO How should "parts" be validated?
  property "parts", :objekt, range: "SciCollection", inverse: "parts"
  property "description", :text, cardinality: 1
  property "digital_collection", :objekt, range: "DigitalRepresentation", inverse: "sci_collection"
  # Bestaende
  property "subject", :objekt, range: "Subject", inverse: "is_subject", facet_link: "subject"
  property "genre", :objekt, range: "ObjectGenre", inverse: "is_genre", facet_link: "genre"
  property "living_being", :objekt, range: "LivingBeing", inverse: "is_living_being", facet_link: "livingbeing"
  property "has_holdinggroup", :objekt, range: "HoldingGroup", inverse: "is_holdinggroup"
  # Information
  property "homepage", :objekt, range: "WebResource", inverse: "is_homepage"
  property "collection_portal", :objekt, range: "WebResource", inverse: "is_collection_portal"
  property "other_web_resource", :objekt, range: "WebResource", inverse: "is_other_web_resource"
  property "has_database_internal", :objekt, range: "WebResource", visible_for: :manager, inverse: "is_internal_database_for"
  # Kontakt & Infrastruktur
  property "address", :objekt, range: "Address", inverse: "is_address", cardinality: 1
  property "email", :email
  property "phone", :phone
  property "curator", :objekt, range: "Curatorship", inverse: "curated_collection"
  property "opening_hours", :text, cardinality: 1
  # Aktivitaet
  property "used_in_activity", :objekt, range: "CollectionActivity", inverse: "used_collection"
  # Konzept + Budget
  #property "has_collection_concept", :bool, cardinality: 1
  property "has_collection_concept", :string, cardinality: 1, options: ["yes", "no","novalue"]
  property "has_usage_regulation", :string, cardinality: 1, options: ["yes", "no","novalue"]
  property "has_budget", :string, cardinality: 1, options: ["yes", "no","novalue"], visible_for: :manager
  # Lehre
  property "academic_teaching", :select_option, options: ["academic_teaching_interdisciplinary","academic_teaching_basic","none"]
  property "has_documented_history", :string, cardinality: 1, visible_for: :manager, options: ["has_documented_history_collection", "has_documented_history_objects","none"]
  property "provenance_status", :select_option, visible_for: :manager, options: ["provenance_status_colonial",
                                                                                  "provenance_status_antiquities",
                                                                                  "provenance_status_human_remains",
                                                                                  "provenance_status_endangered_species",
                                                                                  "provenance_status_ns",
                                                                                  "none"]



  default_hierarchy_predicate "has_part"

  access_rule action: [:edit, :delete], minimum_required_role: :manager
  access_rule action: [:create], minimum_required_role: :member

  # discover:
  category "collection"
  headline :self
  subheadline :has_current_keeper
  description :description
  facet :subject,       :subject, {include_hidden: [:alt_label, :label_en]}
  facet :genre,         :genre, {follow_hierarchy: true, include_hidden: [:alt_label, :label_en]}
  facet :collection,    :self
  facet :person,        :curator, :curator
  facet :organisation,  :has_current_keeper
  facet :organisationtype, :has_current_keeper, :organisation_type
  facet :organisationtype, :special_form
  facet :place,         :location
  facet :place,         :address, :location
  facet :collectiontype,:collection_type
  facet :reproduction,  :digital_collection, :digital_collection ,:reproduction
  facet :collectionrole, :role
  facet :state,         :address, :location, :state
  facet :state,         :has_current_keeper, :address, :location, :state
  facet :activitytype,  :used_in_activity, :activity_type
  facet :livingbeing,   :living_being
  
  # (see Individual#facet_value)
  def facet_value
    inline_label
  end

  # (see Individual.hierarchical?)
  def self.hierarchical?
    true
  end

  # (see Individual#automatically_editable_by)
  def automatically_editable_by
    ret = []

    # all Persons connected via Curatorship may edit this SciCollection
    curator_value.each do |curator|
      ret.push curator.curator_value
    end

    koord_type = OrganisationType.find_by(descriptive_id: 'CollectionCoordination')
    # all Persons that are connected via "person" to an Organisation of type
    # "Sammlungskoordination" that is connected to this SciCollection via
    # "associated_organisation"
    associated_organisation_value.each do |organisation|
      if organisation.organisation_type_value.include?(koord_type)
        organisation.person_value.each do |person|
          ret.push person
        end
      end
    end

    uni_type = OrganisationType.find_by(descriptive_id: 'University')
    # all Persons that are connected via "person" to an Organisation of type
    # "Sammlungskoordination" that is connected to an Organiastion of type
    # "Universität" via "related_actor" that is connected to this SciCollection
    # via "has_current_keeper" or "associated_organisation"
    unis = Set.new
      .merge(has_current_keeper_value)
      .merge(associated_organisation_value)
      .keep_if { |org| org.organisation_type_value.include?(uni_type) }

    persons = unis.to_a
      .collect { |uni| uni.related_actor_value }
      .flatten
      .select { |org| org.try(:organisation_type_value) && org.organisation_type_value.include?(koord_type) }
      .collect! { |koord| koord.person_value }
      .flatten

    Set.new(persons)
      .each do |person|
        ret.push person
      end
    ret
  end


  # @return statistics about this collections holdings
  def holdings_stats
    raise NotImplementedError
  end

  def all_partial_collections_and_self acc=[]
    if has_part
      parts = has_part.collect{|prop| prop.objekt}

      return acc + [self] + parts.collect{|partcoll| partcoll.all_partial_collections_and_self(acc)}.flatten
    else
      return [self]
    end
  end

  def sum_holding_figures
    quantity_hsh = {figure: 0, ca: false}
    sum = {objects: quantity_hsh.clone, indexed: quantity_hsh.clone, digitized: quantity_hsh.clone, online_available: quantity_hsh.clone}
    hgs = self.has_holdinggroup_value
    hgs.each do |hg|
      if q1 = hg.object_quantity_value
        sum[:objects][:figure] += (q1.figure_value).to_i
        sum[:objects][:ca] ||=  q1.circa_value
      end
      if q2 = hg.indexed_quantity_value
        sum[:indexed][:figure] += (q2.figure_value).to_i
        sum[:indexed][:ca] ||=  q2.circa_value
      end
      if q3 = hg.digitized_quantity_value
        sum[:digitized][:figure] += (q3.figure_value).to_i
        sum[:digitized][:ca] ||=  q3.circa_value
      end
      if q4 = hg.online_available_quantity_value
        sum[:online_available][:figure] += (q4.figure_value).to_i
        sum[:online_available][:ca] ||=  q4.circa_value
      end
    end

    return sum
  end

  def holding_figures
    holding_hashes = []
    quantity_hsh = {figure: 0, ca: false}

    hgs = self.has_holdinggroup_value
    hgs.each do |hg|

      hg_hsh = {genre: hg.safe_value("genre"),
                objects: quantity_hsh.clone,
                indexed: quantity_hsh.clone,
                digitized: quantity_hsh.clone,
                online_available: quantity_hsh.clone}

      if q1 = hg.object_quantity_value
        hg_hsh[:objects][:figure] = q1.figure_value
        hg_hsh[:objects][:ca] =  q1.circa_value
      end
      if q2 = hg.indexed_quantity_value
        hg_hsh[:indexed][:figure] = q2.figure_value
        hg_hsh[:indexed][:ca] =  q2.circa_value
      end
      if q3 = hg.digitized_quantity_value
        hg_hsh[:digitized][:figure] = q3.figure_value
        hg_hsh[:digitized][:ca] =  q3.circa_value
      end
      if q4 = hg.online_available_quantity_value
        hg_hsh[:online_available][:figure] = q4.figure_value
        hg_hsh[:online_available][:ca] =  q4.circa_value
      end
      holding_hashes << hg_hsh
    end

    holding_hashes.sort_by! { |hsh| hsh[:objects][:figure] }
    holding_hashes.reverse!
    return holding_hashes
  end
  
  def self.uni_collections
    org_types = OrganisationType.where(id: [2,8])
    unis = Organisation.all.select{|o| (o.organisation_type_value.collect{|t| t.id} & [2,8]).present?}
    uni_ids = unis.collect{|uni| uni.id}
    scicolls = SciCollection.all.select{|c| c.visible_for_value == nil || c.visible_for_value == "public"}
    scicolls.select!{|c| (c.has_current_keeper_value.collect(&:id) & uni_ids).present?}
    #sci_coll_ids = unis.collect{|uni| uni.current_keeper.objekt_id}.flatten.uniq
    
    
    scicolls
  end
  
  # @return all parts and parts of parts as a hash
  def list_recursive_parts accu=[]
    accu.append self
    has_part_value.each do |coll|
      # prevent infinite loop
      unless accu.include? coll
        coll.list_recursive_parts accu
      end
    end
    return accu
  end

  private

  def set_labels
    loc = self.safe_value "location"
    if loc.length > 0
      self.inline_label = label + ", " + loc
    else
      self.inline_label = label
    end
  end
end
