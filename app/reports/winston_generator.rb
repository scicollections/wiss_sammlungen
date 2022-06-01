# Imports and structures (i.e. generates) data from maya database.
#
# @example
#   WinstonGenerator.run! "2017-07-01"
class WinstonGenerator
  # Starts the data generation of maya-data and saves the generated
  # data in a report object of date `date`, if a report of that date
  # exists, this report is overridden; if no date is passed, the
  # current Date is used.
  #
  # @param date [String]
  def self.run! date=nil
    # DB Logging ausschalten
    ActiveRecord::Base.logger.level = 1

    # Clear rails cache to be sure that e.g. uni_coll_data
    # in winston_controller.rb is not cached
    Rails.cache.clear

    # Parse date if passed as string
    date = Date.parse(date) if String === date

    # Use current date if none is passed
    date ||= Date.today

    # reuse existing report with ID 1
    if rep = Report.find_by(date: date)
      if rep.locked
        puts "A report already exists for #{date} and it's locked."
        puts "Exiting generator."
        return
      end

      print "A report already exists for #{date}. Do you want to replace it? [y/n] "
      unless gets.strip.downcase == "y"
        puts "Exiting generator."
        return
      end

      puts "Replace Report (#{date})"
      rep.touch
      ReportDatum.where(report_id: rep.id).delete_all
    else
      puts "Create Report (#{date})"
      rep = Report.create(date: date)
    end

    @universities = []
    @sci_collections = []
    @digital_collections = []

    # Generate university data first, because it will populate the above arrays
    puts "Generate University Data"
    generate_university_data rep

    puts "Generate Global Data"
    generate_global_data rep

    puts "Generate Digital Collection Data"
    generate_digital_collection_data rep

    return "Finished WinstonGenerator.run"
  end

  # Creates the global data sets and associates them with the passed report.
  def self.generate_global_data report
    # Anteile Sammlungsart
    acc_coll_type = Hash.new(0)
    # #Sammlungen mit Fach x
    acc_total_collections_subjects = Hash.new(0)
    # coll history documentation dependent on coll types
    acc_documented_history_coll_types = Hash.new {  |hash, key| hash[key] = Hash.new(0) }
    # coll history documentation dependent on subjects
    acc_documented_history_subjects = Hash.new {  |hash, key| hash[key] = Hash.new(0) }
    # academic teaching usage dependent on coll types
    acc_academic_teaching_coll_types = Hash.new {  |hash, key| hash[key] = Hash.new(0) }
    # academic teaching usage dependent on subjects
    acc_academic_teaching_subjects = Hash.new {  |hash, key| hash[key] = Hash.new(0) }
    # provenance info dependent on coll types
    acc_provenance_coll_types = Hash.new {  |hash, key| hash[key] = Hash.new(0) }
    # provenance info usage dependent on subjects
    acc_provenance_subjects = Hash.new {  |hash, key| hash[key] = Hash.new(0) }
    # total provenance
    acc_total_provenance = Hash.new(0)

    # documented coll history dependent on provenance info
    acc_documented_history_provenance = Hash.new {  |hash, key| hash[key] = Hash.new(0) }
    acc_usage_regulation_subjects = Hash.new {  |hash, key| hash[key] = Hash.new(0) }
    acc_budget_subjects = Hash.new {  |hash, key| hash[key] = Hash.new(0) }
    acc_collection_concept_subjects = Hash.new {  |hash, key| hash[key] = Hash.new(0) }
    acc_usage_regulation_coll_types = Hash.new {  |hash, key| hash[key] = Hash.new(0) }
    acc_budget_coll_types = Hash.new {  |hash, key| hash[key] = Hash.new(0) }
    acc_collection_concept_coll_types = Hash.new {  |hash, key| hash[key] = Hash.new(0) }
    acc_collection_concept_total = Hash.new(0)
    acc_budget_total = Hash.new(0)
    acc_usage_regulation_total = Hash.new(0)
    acc_curatorship_counting = {colls_without_curator: 0, colls_with_one_curator: 0, colls_with_multi_curators: 0}

    curatorship_fluctuation_hash = CustomQueries.curatorship_fluctuation (report.date - 1.years),report.date, print_output: false


    @sci_collections.each do |coll|
      # Anteile Sammlungsart
      type = coll.safe_value "collection_type"
      acc_coll_type[type] += 1

      # count subjects
      coll.safe_values("subject").each do |subject|
        acc_total_collections_subjects[subject] += 1
      end


      # coll history documentation dependent on coll_types and subjects
      coll_history_value = nil
      if coll.safe_values("has_documented_history").include? "has_documented_history_collection"
        coll_history_value = "has_documented_history_collection"
      elsif coll.safe_values("has_documented_history").include? "has_documented_history_objects"
        coll_history_value = "has_documented_history_objects"
      end
      acc_documented_history_coll_types[type][coll_history_value] += 1

      coll.safe_values("subject").each do |subject|
        acc_documented_history_subjects[subject][coll_history_value] += 1
      end


      # academic teaching dependent on coll_types and subjects
      coll.safe_values("academic_teaching").each do |teaching|
        acc_academic_teaching_coll_types[type][teaching] += 1

        coll.safe_values("subject").each do |subject|
          acc_academic_teaching_subjects[subject][teaching] += 1
        end
      end
      # provenance
      coll.safe_values("provenance_status").each do |provenance_state|
        acc_provenance_coll_types[type][provenance_state] += 1

        coll.safe_values("subject").each do |subject|
          acc_provenance_subjects[subject][provenance_state] += 1
        end
        
        # total provenance
        acc_total_provenance[provenance_state] += 1

        # history dependent on provenance
        
        acc_documented_history_provenance[coll_history_value][provenance_state] += 1
        
      end
      
      # usage regulation
      if coll.has_usage_regulation
        coll.safe_values("subject").each do |subject|
          acc_usage_regulation_subjects[subject][coll.safe_value "has_usage_regulation"] += 1
        end
        acc_usage_regulation_coll_types[type][coll.safe_value "has_usage_regulation"] += 1
        acc_usage_regulation_total[coll.safe_value "has_usage_regulation"] += 1
      end
      # budget
      if coll.has_budget
        coll.safe_values("subject").each do |subject|
          acc_budget_subjects[subject][coll.safe_value "has_budget"] += 1
        end
        acc_budget_coll_types[type][coll.safe_value "has_budget"] += 1
        acc_budget_total[coll.safe_value "has_budget"] += 1
      end
      # collection concept
      if coll.has_collection_concept
        coll.safe_values("subject").each do |subject|
          acc_collection_concept_subjects[subject][coll.safe_value "has_collection_concept"] += 1
        end
        acc_collection_concept_coll_types[type][coll.safe_value "has_collection_concept"] += 1
        acc_collection_concept_total[coll.safe_value "has_collection_concept"] += 1
      end
      
      curator_count = coll.safe_values("curator").size
      if curator_count == 0
        acc_curatorship_counting[:colls_without_curator] += 1
      elsif curator_count == 1
        acc_curatorship_counting[:colls_with_one_curator] += 1
      elsif curator_count > 1
        acc_curatorship_counting[:colls_with_multi_curators] += 1
      end

    end
    
    

    # rename key
    acc_coll_type["keine Angabe"] = acc_coll_type.delete("")
    # TODO do this for other accumulators

    # output into report_data objects
    CollectionType.all.to_a.push({label: "keine Angabe"}).each do |coll| # push "" to count number of collections with no type attribute
      label = coll[:label]
      create_rd(report, "anteile_sammlungsart", {
        string1: label,
        int2: acc_coll_type[label],
        # save reference to report in int3; used to distinguish the global "anteile_sammlungsart" from "anteile_sammlungsart" for each university
        int3: report.id,
        int4: coll[:id], # is nil for "keine Angabe"
        }
      )
    end
    Subject.all.each do |subject|
      label = subject[:label]
      create_rd(report, "sammlungen_mit_fach", {
        string1: label,
        int2: acc_total_collections_subjects[label],
        int3: report.id,
        int4: subject[:id], # is nil for "keine Angabe"
        }
      )
    end

    # absolute numbers
    create_rd(report, "absolut_sammlungen", { int1: @sci_collections.size } )
    create_rd(report, "absolut_universitaeten", {int1: @universities.size } )

    documentation_states = SciCollection.new.predicates["has_documented_history"][:options]
    teaching_states = SciCollection.new.predicates["academic_teaching"][:options]
    provenance_states = SciCollection.new.predicates["provenance_status"][:options]


    # storage per collection type
    CollectionType.all.to_a.push({label: "keine Angabe"}).each do |type_hash|
      type = type_hash[:label]

      # documented coll history
      documentation_states.each do |doc_info|
        create_rd(report, "coll_type_documented_history", {
          string1: doc_info,
          string2: type,
          int2: acc_documented_history_coll_types[type][doc_info],
          int4: type_hash[:id] # is nil for "keine Angabe"
          }
        )
      end

      # academic teaching
      teaching_states.each do |teaching|
        create_rd(report, "coll_type_academic_teaching", {
          string1: teaching,
          string2: type,
          int2: acc_academic_teaching_coll_types[type][teaching],
          int4: type_hash[:id] # is nil for "keine Angabe"
          }
        )
      end
      # provenance
      provenance_states.each do |provenance_state|
        create_rd(report, "coll_type_provenance", {
          string1: provenance_state,
          string2: type,
          int2: acc_provenance_coll_types[type][provenance_state],
          int4: type_hash[:id] # is nil for "keine Angabe"
          }
        )
      end
      # budget
      # usage regulation
      # collection concept
      
     
      

    end

    # storage per subject
    Subject.all.to_a.push({label: "keine Angabe"}).each do |subject_hash|
      subject = subject_hash[:label]

      # documented history
      documentation_states.each do |doc_info|
        create_rd(report, "subject_documented_history", {
          string1: doc_info,
          string2: subject,
          int2: acc_documented_history_subjects[subject][doc_info],
          int4: subject_hash[:id] # is nil for "keine Angabe"
        })
      end

      # usage in academic teaching
      teaching_states.each do |teaching|
        create_rd(report, "subject_academic_teaching", {
          string1: teaching,
          string2: subject,
          int2: acc_academic_teaching_subjects[subject][teaching],
          int4: subject_hash[:id] # is nil for "keine Angabe"
          }
        )
      end
      # usage in academic teaching
      provenance_states.each do |provenance_state|
        create_rd(report, "subject_provenance", {
          string1: provenance_state,
          string2: subject,
          int2: acc_provenance_subjects[subject][provenance_state],
          int4: subject_hash[:id] # is nil for "keine Angabe"
          }
        )
      end
    end

    # store history dependent on provenance
    provenance_states.each do |provenance_state|
      documentation_states.each do |documentation_state|
        create_rd(report, "documented_history_provenance", {
          string1: provenance_state,
          string2: documentation_state,
          int2: acc_documented_history_provenance[documentation_state][provenance_state]
          }
        )
      end
    end
    # store total provenance info
    provenance_states.each do |provenance_state|
      create_rd(report, "total_provenance_info", {
        string1: provenance_state,
        int2: acc_total_provenance[provenance_state]
        }
      )
    end

    create_rd(report, "collections_curatorship_fluctuation",{
      int2: curatorship_fluctuation_hash[:collections_won_curator],
      int3: curatorship_fluctuation_hash[:collections_lost_curator],
      int4: curatorship_fluctuation_hash[:collections_wonandlost_curator]
    })
    
    acc_budget_coll_types["Keine Angabe"] = acc_budget_coll_types.delete("")
    acc_usage_regulation_coll_types["Keine Angabe"] = acc_usage_regulation_coll_types.delete("")
    acc_collection_concept_coll_types["Keine Angabe"] = acc_collection_concept_coll_types.delete("")
    
    # budget per coll type
    acc_budget_coll_types.each do |coll_type,hash|
      create_rd(report, "coll_type_budget", {
        string1: coll_type,
        int2: acc_budget_coll_types[coll_type]["yes"],
        int3: acc_budget_coll_types[coll_type]["no"],
        int4: acc_budget_coll_types[coll_type]["novalue"]
        }
      )
    end
    
    # usage regulation per coll type
    acc_usage_regulation_coll_types.each do |coll_type,hash|
      create_rd(report, "coll_type_usage_regulation", {
        string1: coll_type,
        int2: acc_usage_regulation_coll_types[coll_type]["yes"],
        int3: acc_usage_regulation_coll_types[coll_type]["no"],
        int4: acc_usage_regulation_coll_types[coll_type]["novalue"]
        }
      )
    end
    
    # coll concept per coll type
    acc_collection_concept_coll_types.each do |coll_type,hash|
      create_rd(report, "coll_type_collection_concept", {
        string1: coll_type,
        int2: acc_collection_concept_coll_types[coll_type]["yes"],
        int3: acc_collection_concept_coll_types[coll_type]["no"],
        int4: acc_collection_concept_coll_types[coll_type]["novalue"]
        }
      )
    end
    
    create_rd(report, "total_collection_concept", {
      int2: acc_collection_concept_total["yes"],
      int3: acc_collection_concept_total["no"],
      int4: acc_collection_concept_total["novalue"]
      }
    )
    create_rd(report, "total_usage_regulation", {
      int2: acc_usage_regulation_total["yes"],
      int3: acc_usage_regulation_total["no"],
      int4: acc_usage_regulation_total["novalue"]
      }
    )
    create_rd(report, "total_budget", {
      int2: acc_budget_total["yes"],
      int3: acc_budget_total["no"],
      int4: acc_budget_total["novalue"]
      }
    )
    create_rd(report, "coll_curatorship_counting", {
      int1: acc_curatorship_counting[:colls_without_curator],
      int2: acc_curatorship_counting[:colls_with_one_curator],
      int3: acc_curatorship_counting[:colls_with_multi_curators]
      }
    )
    

  end

  # Creates the data sets for all universities and associates them with the passed report.
  def self.generate_university_data report
    # Bundeslaender
    states = Hash.new
    # while passing through the Organisations accumulate all considered elements
    # in Sets to avoid double-counting; create according ReportDatums after
    # going through all @universities
    STATES.clone.merge!(nil=>"kein Bundesland zugeordnet")
      .each do |key, val|
        states[key] = {
          name: val,
          code: key,
          universities: Set.new,
          collections: Set.new,
          active_collections: Set.new,
          digitized_collections: Set.new,
          collection_coordination_count: 0,
          collection_policy_count: 0,
          webportal_count: 0,
          object_portal_count: 0
        }
      end

    # Create datum for each university with the appropriate properties
    Organisation.universities.each do |uni|
      next unless uni.public?
      next unless uni.safe_value("country") == "Deutschland"

      collections = uni.current_keeper_value.find_all(&:public?)
      next unless collections.any?

      @universities << uni

      puts "... #{uni[:label]} (#{uni[:id]})"

      # if some unis' location attribute is not present, then the location is taken from the address
      place = uni.safe_value("location")
      if place.blank? && uni.address.present?
        place = uni.address.first.value.safe_value "location"
      end

      # save initially so this report_datum already has its id set
      uni_dat = report.universities.create(
        maya_id: uni.id,
        name: uni.label,
        place: place,
        state_admin1: STATES.key(uni.safe_value "state"),
        has_coll_policy: uni.safe_value("collections_order"), # Sammlungsordnung
        has_coll_website: uni.safe_value("collection_portal").present?, # Sammlungsportal
        has_object_portal: uni.safe_value("object_portal").present?, # Objektportal
      )

      # get state counter datum from states hash which will be used to multiply in the counting process
      state_dat = states[uni_dat.state_admin1]
      # increase state-organisation counter
      state_dat[:universities].add(uni)

      # Sammlungskoordination
      # initially set has_coll_coord ('Hat Sammlungskoordination') to false
      uni_dat.has_coll_coord = false
      # all "verknuepfter Akteur" of universitaet with organisation_type == Sammlungskoordination
      uni.related_actor_value.each do |actor|
        next unless actor.safe_value("organisation_type") == "Sammlungskoordination"
        next unless actor.public?

        koord_dat = uni_dat.collection_coordinations.create(
          report_id: report.id,
          maya_id: actor.id,
          name: actor.label,
        )

        # associated persons with Sammlungskoordination
        actor.person_value.each do |person|
          next unless person.public?

          koord_dat.contacts.create(
            report_id: report.id,
            maya_id: person.id,
            name: person.label,
          )
        end

        # if at least one sammlungskoordination for an universitaet is found, then set
        # universitaet's bool1 ('Hat Sammlungskoordination') to true
        uni_dat.has_coll_coord = true
      end

      # increase state-wide counters
      state_dat[:collection_coordination_count] += 1 if uni_dat.has_coll_coord
      state_dat[:collection_policy_count] += 1 if uni_dat.has_coll_policy
      state_dat[:webportal_count] += 1 if uni_dat.has_coll_website
      state_dat[:object_portal_count] += 1 if uni_dat.has_object_portal

      # Sammlungen

      # Initialize counters
      uni_dat.coll_count = 0
      uni_dat.active_coll_share = 0 # This isn't really the share, but an absolute number.
      uni_dat.admin_coll_share = 0 # Same here.
      uni_dat.digital_coll_share = 0 # Same here.

      types = Hash.new(0) # aggregator with 0 as default value
      subjectsHash = Hash.new(0)

      collections.each do |coll|
        # increase state collection counter
        state_dat[:collections].add(coll)

        # check if this collection is a sub-set of another collection
        # if this is the case, the sub-collection itself does not have a collection_type
        # and the type must be inferred from the super-collection
        type = coll.safe_value "collection_type"
        if type.blank? && coll.part_of.present?
          # adopt type of the first connected collection, assume that this collection *has*
          # a collection type and is not another partial-collection
          type = coll.part_of.first.value.safe_value "collection_type"
        end

        # add subjects
        subjects = coll.safe_values "subject"

        # Only add each coll to @sci_collection once (could make that a Set), but create
        # sam_dat anyway, since we don't have many-to-many associations between SciCollections and
        # universities in Winston.
        unless @sci_collections.include?(coll)
          @sci_collections << coll
        end

        sam_dat = uni_dat.collections.create(
          report_id: report.id,
          maya_id: coll.id,
          name: coll.label,
          admin1: uni_dat.state_admin1,
          is_active: coll.safe_value("active_collection"),
          has_contact: coll.safe_values("curator").any?,
        )

        coll.digital_collection_value.each do |dr| # "dr" is for "digital representation"
          dc = dr.digital_collection_value
          next unless dc.public?

          # Be careful not to save the same digital collection twice
          unless @digital_collections.include?(dc)
            @digital_collections << dc
            report.digital_collections.create(
              maya_id: dc.id,
              name: dc.label,
            )
          end

          # NB We could also save dr.id here, but we have decided not to (2017-06-16)
          sam_dat.digital_representations.create(digital_collection_id: dc.id)
        end

        sam_dat.has_digital_collection = sam_dat.digital_representations.any?
        sam_dat.save

        # counters
        uni_dat.coll_count += 1
        uni_dat.active_coll_share += 1 if sam_dat.is_active
        uni_dat.admin_coll_share += 1 if sam_dat.has_contact
        uni_dat.digital_coll_share += 1 if sam_dat.has_digital_collection
        types[type] += 1
        subjects.each {|subject| subjectsHash[subject] += 1}
        state_dat[:active_collections].add(coll) if sam_dat.is_active
        state_dat[:digitized_collections].add(coll) if sam_dat.has_digital_collection
      end

      # save University ReportDatum to write counters etc. to DB
      uni_dat.save

      # rename key "" to "keine Angabe" if present
      if types.has_key?("")
        types["keine Angabe"] = types.delete("")
      end

      # save uni-level collection type distribution
      types.each do |type, count|
        maya_indi = CollectionType.find_by(label: type)
        maya_id = maya_indi ? maya_indi.id : nil

        create_rd(report, "anteile_sammlungsart", {
          string1: type,
          int2: count,
          int3: uni_dat.id,
          int4: maya_id,
        })
      end

      # save uni-level collection subject shares
      subjectsHash.each do |subject, count|
        maya_indi = Subject.find_by(label: subject)
        maya_id = maya_indi ? maya_indi.id : nil

        create_rd(report, "anteile_fachgebiet", {
          string1: subject,
          int2: count,
          int3: uni_dat.id,
          int4: maya_id,
        })
      end
    end

    # create ReportDatums for each Bundesland, based on the sizes of the
    # accumulated Sets
    states.each do |key, val|
      maya_indi = State.find_by(label: val[:name])
      maya_id = maya_indi ? maya_indi.id : nil

      report.states.create(
        name: val[:name],
        admin1: key,
        university_count: val[:universities].size,
        collection_count: val[:collections].size,
        active_collection_count: val[:active_collections].size,
        collection_coordination_count: val[:collection_coordination_count],
        collection_policy_count: val[:collection_policy_count],
        webportal_count: val[:webportal_count],
        maya_id: maya_id,
        digitized_collection_count: val[:digitized_collections].size,
        object_portal_count: val[:object_portal_count]
      )
    end
  end

  # Creates the digital-collection data sets and associates them with the passed report.
  def self.generate_digital_collection_data report
    # Anteil digitalisierter Sammlungen
    acc = { int1: 0, int2: 0 }
    @sci_collections.each do |col|
      if col.digital_collection.size > 0
        acc[:int1] += 1
      else
        acc[:int2] += 1
      end
    end
    create_rd(report, "dc_anteile_sammlungen", acc)

    # Sammlungsarten
    acc = Hash.new(0)
    acc_dig = Hash.new(0)
    @sci_collections.each do |col|
      type = col.safe_value "collection_type"
      acc[type] += 1
      if col.digital_collection.size > 0
        acc_dig[type] += 1
      end
    end

    # rename key
    acc_dig["keine Angabe"] = acc.delete("")

    # output into report_data objects
    CollectionType.all.to_a.push({label: "keine Angabe"}).each do |coll| # push "" to count number of collections with no type attribute
      type = coll[:label]
      create_rd(report, "dc_anteile_sammlungsart", {
        string1: type,
        int1: acc[type], # total collections of this type
        int2: acc_dig[type], # collections with digital collection of this type
        int3: report.id, 
      })
    end

    # Fachgebiete
    acc = Hash.new(0)
    sci_cols = Hash.new(0)
    @sci_collections.each do |col|
      col.subject.each do |prop|
        sci_cols[prop.value] += 1
        acc[prop.value] += 1 if col.digital_collection.size > 0
      end
    end
    # sort by Subject "relevance" (number of is_subject-links to SciCollection)
    acc = acc.to_a.sort do |a, b|
      sci_cols[a[0]] <=> sci_cols[b[0]]
    end.reverse

    acc.each do |subj, count|
      create_rd(report, "dc_anteile_fachgebiet", {
        string1: subj.label,
        # number of collections of this Subject with digital collection
        int1: count,
        # "relevance" of this Subject
        int2: sci_cols[subj],
        # save quotient digitalized collections / collections total
        float1: count.to_f / sci_cols[subj].to_f, # TODO Why? We don't save the other quotients
        # save reference to report in int3; used to distinguish the global "dc_anteile_sammlungsart" from "dc_anteile_sammlungsart" for each university
        int3: report.id, # TODO Why? There doesn't seem to be a "for each university" variant of this
        int4: subj.id,
      })
    end

    # Sammlungen mit|ohne Digitalisate
    create_rd(report, "dc_digitalisate", {
      int1: @digital_collections.select{|dc|dc.reproduction.size > 0}.size,
      int2: @digital_collections.size,
      int3: report.id 
    })

    # Art der Digitalisate
    rep_type_counts = Hash.new(0)
    @digital_collections.each do |dc|
      uniq_rep_types = dc
        .reproduction_value
        .map(&:reproduction_type_value)
        .uniq

      # We don't want to count any type twice for this digital collection. (In practice, digital
      # collections shouldn't have two digital reproductions with the same type, but this is not
      # enforced.)
      uniq_rep_types.each do |type|
        rep_type_counts[type] += 1
      end
    end

    rep_type_counts.each do |type, count|
      create_rd(report, "dc_anteile_digitalisate", {
        int1: count,
        string1: type.label,
        int2: type.id,
        int3: report.id, # TODO Why?
      })
    end

    # Qualität Bilder
    # rep = reproduction
    # iq = image quality
    # dc = digital collection

    iq_counts = Hash.new(0)

    dcs_with_images_reps = @digital_collections.each do |dc|
      reps = dc.reproduction_value
      image_reps = reps.find_all do |rep|
        rep.reproduction_type_value.safe_value("type_label") == "Image"
      end

      if image_reps.any?
        # Usually there will only be one reproduction of type Image. But this is not guaranteed,
        # and therefore we need to decide which one to count. Of course, we'll want to count the
        # one with the best image quality.

        iqs = image_reps.map { |rep| rep.image_quality_value }
        # NB image_quality is sometimes nil, and its sort_value COULD also be nil (but in practice
        # it's not).
        sorted_iqs = iqs.sort_by { |iq| (iq && iq.sort_value_value) || 0 }
        best_iq = sorted_iqs.last

        # Increment count for best image quality
        iq_counts[best_iq] += 1
      end
    end

    iq_counts.each do |iq, count|
      label = iq ? iq.label : "keine Angabe"
      maya_id = iq ? iq.id : nil
      sort_value = (iq && iq.sort_value_value) || 0

      create_rd(report, "dc_bilder_qualitaet", {
        int1: count,
        int2: sort_value,
        string1: label,
        int3: report.id,
        int4: maya_id,
      })
    end
  end

  # Creates a new ReportDatum with provided name and values set like in values_hash.
  #
  # @param report [Integer] The new ReportDatum's report_id.
  # @param name [String] The new ReportDatum's name value.
  # @param values_hash [Hash] A Hash whose keys (:symbols) are a ReportDatum's data
  #   fields' names (like :int1, :bool4 ...) and values of the respective type.
  #
  # @example
  #   create_rd(Report.first, "dc_bilder_qualitaet", {
  #     int1: 34,
  #     string3: "blonkers",
  #     int3: Report.first.id
  #   })
  #
  # @return [ReportDatum]
  def self.create_rd report=nil, name=nil, values_hash={}
    dat = ReportDatum.new
    dat.report = report if report
    dat.legacy_name = name if name
    if values_hash
      values_hash.each do |k, v|
        dat[k] = v
      end
    end
    dat.save
    dat
  end

  # A globally accessible hash of states.
  STATES = {
    "01"=>"Baden-Württemberg",
    "02"=>"Bayern",
    "03"=>"Bremen",
    "04"=>"Hamburg",
    "05"=>"Hessen",
    "06"=>"Niedersachsen",
    "07"=>"Nordrhein-Westfalen",
    "08"=>"Rheinland-Pfalz",
    "09"=>"Saarland",
    "10"=>"Schleswig-Holstein",
    "11"=>"Brandenburg",
    "12"=>"Mecklenburg-Vorpommern",
    "13"=>"Sachsen",
    "14"=>"Sachsen-Anhalt",
    "15"=>"Thüringen",
    "16"=>"Berlin",
  }
end
