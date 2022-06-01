# Custom Queries
# 
# Collection of small queries to be run on our data

class CustomQueries
  def self.uni_collections_with_small
    uni_sci_colls = []
    sci_colls_with_small = []
    uni_type = OrganisationType.all.where(label: "Universität")
    SciCollection.all.each do |sci_coll|
      orga_types = sci_coll.has_current_keeper_value.map{|keeper|keeper.organisation_type_value}
      small_subjects = sci_coll.subject_value.map{|subject| subject.small_value}
      if !orga_types.blank? && orga_types.include?(uni_type)
        uni_sci_colls.push(sci_coll) 
        if small_subjects.any?
          sci_colls_with_small.push(sci_coll)
        end
      end
    end
    print "Uni-Sammlungen: ", uni_sci_colls.length
    print "\n"
    print "Mit kleinen Fächern: ", sci_colls_with_small.length
    print "\n"
  end
  
  # Method to extract and print curatorship fluctuation figures for the timescale of a campaign
  #
  # What's this method doing exactly? 
  # It fetchs all revisions for the time span of the given campaign with predicate `curator` and subject_type `SciCollection`.
  # Distinguishes between create/delete revisions and counts every SciCollection just once.
  # Prints the extracted figures and the total amount of SciCollections that were at least invited in given campaign.
  #
  def self.curatorship_fluctuation startdate, enddate, print_output: true
    
    
    revs = Revision.where("created_at > ? AND created_at < ?",startdate,enddate).
            where(predicate: "curator", subject_type: "SciCollection")
    curatorships_created = revs.where(action: "prop_create").collect{|rev| rev.subject_id}.uniq
    curatorships_deleted = revs.where(action: "prop_delete").collect{|rev| rev.subject_id}.uniq
    curatorships_changed = curatorships_created & curatorships_deleted
    affected = (curatorships_created + curatorships_deleted).uniq
    collections_all = SciCollection.count
    
    
    if print_output
    
      # Header
      print "\n"
      print "Eckdaten:\n"
      print "=========\n"
      print "Von: #{startdate}\n"
      print "Bis:  #{enddate}\n"
      printf "Sammlungen gesamt:          %4d\n",
        collections_all
    
      # Daten
      print "Daten:\n"
      print "======\n"
      # Ansprechp. hinzugefuegt
      printf "Mind. 1 Ansprechp. hinzugefügt: %4d (%4.1f%% / %4.1f%%)\n", 
        curatorships_created.count, 
        ((curatorships_created.count.to_f/collections_all.to_f) * 100),
        ((curatorships_created.count.to_f/cnumbers_by_status.values.sum.to_f) * 100)
      # Ansprechp. entfernt
      printf "Mind. 1 Ansprechp. entfernt:    %4d (%4.1f%% / %4.1f%%)\n", 
        curatorships_deleted.count,
        ((curatorships_deleted.count.to_f/collections_all.to_f) * 100),
        ((curatorships_deleted.count.to_f/cnumbers_by_status.values.sum.to_f) * 100)
      # Ansprechpartnerwechsel
      printf "Ansprechpartnerwechsel**:       %4d (%4.1f%% / %4.1f%%)\n", 
        curatorships_changed.count,
        ((curatorships_changed.count.to_f/collections_all.to_f) * 100),
        ((curatorships_changed.count.to_f/cnumbers_by_status.values.sum.to_f) * 100)
      # Betroffene Sammlungen gesamt
      printf "Betroffene Sammlungen gesamt:   %4d (%4.1f%% / %4.1f%%)\n", 
        affected.count,
        ((affected.count.to_f/collections_all.to_f) * 100),
        ((affected.count.to_f/cnumbers_by_status.values.sum.to_f) * 100)
    
      print "\n"
      print "*Sammlungen mit Reaktionen: Fertig gemeldet, Abgeschlossen, Blockiert\n"
      print "**Ansprechpartnerwechsel: Mind. 1 Ansprechpartner entfernt & mind. 1 Ansprechpartner hinzugefügt\n"
      print "\n"
    end

    return {
      collections_won_curator: curatorships_created.count,
      collections_lost_curator: curatorships_deleted.count,
      collections_wonandlost_curator: curatorships_changed.count
    }

  end
  
  def self.curatorship_fluctuation_campaign campaign
    raise "Please provide a valid campaign object" unless campaign
    startdate = campaign.begin
    enddate =campaign.end
    print "Kampagne: #{campaign}\n"
    curatorship_fluctuation_campaign startdate, enddate
    
    cnumbers_by_status = {}
    relevant_status = Campaign::ACTIONASSIGN.values - [:initial, :invited, :in_progress]
    relevant_status.each do |status|
      cnumbers_by_status[status] = campaign.count_survey_targets status
    end
    printf "Sammlungen mit Reaktionen*: %4d (%4.1f%%)\n",
      cnumbers_by_status.values.sum,
      ((cnumbers_by_status.values.sum.to_f/collections_all.to_f) * 100)
    print "\n"
  end
  
  # Mailadressen (nur Adressen) als Liste / versandfertig kommagetrennt 
  # mit diesen Kriterien: 
  # Ansprechpartner:innen Sammlungen & Mitglied Sammlungskoordinationen 
  # von Uni/Hochschule in Baden-Württemberg?
  #
  # collect domains from result: 
  # addrs.collect{|ad| ad.split("@").last}.compact.collect{|dom| dom.split(".")[-2..].join(".")}.flatten.uniq
  def self.state_coll_contacts state
    state_unis = Organisation.generic_institutions_of_higher_education.select{|org| org.address_value.select{|addr| addr.location_value.try(:state_value) == state}.present?}
    state_collections = SciCollection.all.select{|coll| (coll.has_current_keeper_value & state_unis).present?}
    
    coord_type = OrganisationType.find(5)
    state_coordinations = Organisation.all.select{|org| org.organisation_type_value.include? coord_type}.select{|org| (state_unis & org.related_actor_value).size > 0 }
    
    coord_people = state_coordinations.collect{|coord| coord.person_value}.flatten
    coll_people  = state_collections.collect{|coll| coll.curator_value.collect{|curator| curator.curator_value}}.flatten
    
    people = (coord_people + coll_people).flatten
    emails = people.collect{|person| person.email_value.first}.uniq.compact
    return emails.join(",")
  end
  
end