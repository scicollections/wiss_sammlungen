# Controller for "Kennzahlen".
class WinstonController < ApplicationController
  # inject report into handler methods
  before_action :set_report, :set_chart_options

  # Uncomment to use a specific report as default. Otherwise the most recent is used, 
  # as implemented in #set_report
  # DEFAULT_REPORT_DATE = Date.new(2021, 11, 02)

  # @action GET
  # @url /kennzahlen/university/:university_id
  #
  # Single university data-sheet of a specific report.
  def university
    @uni = WinstonUniversity.find_by_maya_id(@report, params[:university_id])
    winston_title @uni.name
    
    @coll_coords = @uni.indi.related_actor_value.sort { |a,b| a.label <=> b.label}
      .select{|actor| actor.safe_values("organisation_type").include? "Sammlungskoordination"}
  end

  # @action GET
  # @url /kennzahlen/:report_id/states
  #
  # Aggregated data-sheet for every state of a specific report.
  def states
    winston_title "Universitäten"
  end

  # @action GET
  # @url /kennzahlen/:report_id/digitale-sammlungen
  def digital_collections
    winston_title "Digitale Sammlungen"

    # Anteil digitalisierter wissenschaftlicher Universitätssammlungen
    dcas = @report.report_datum.where(legacy_name: "dc_anteile_sammlungen").first
    @dc_anteile_sammlungen = {
      "digital zugänglich" => dcas.int1,
      "nicht digital zugänglich" => dcas.int2
    }

    # Sammlungsarten
    total, dig = {}, {}
    max = 0 # maximum is used for chart display
    # int3 resembles the context for "dc_anteile_sammlungsart" ReportDatums; can be a report-/university-id
    @report.report_datum.where(legacy_name: "dc_anteile_sammlungsart", int3: @report.id).each do |rd|
      total[rd.string1] = rd.int1 - rd.int2
      dig[rd.string1] = rd.int2
      max = rd.int1 if rd.int1 > max
    end
    @dc_anteile_sammlungsart_max_value = max
    total.delete("keine Angabe")
    dig.delete("keine Angabe")
    @dc_anteile_sammlungsart = [
      {
        name: "nicht digital zugänglich",
        data: total
      },
      {
        name: "digital zugänglich",
        data: dig
      },
    ]

    # Fachgebiete
    @dc_anteile_fachgebiet = dc_anteile_fachgebiet(30)
    @dc_anteile_fachgebiet_abs = dc_anteile_fachgebiet(30,"absolute")
    @dc_anteile_fachgebiet_full = dc_anteile_fachgebiet
    @dc_anteile_fachgebiet_full_abs = dc_anteile_fachgebiet(nil, "absolute")

    # Digitalisate
    rd = @report.report_datum.where(legacy_name: "dc_digitalisate", int3: @report.id).first
    @dc_digitalisate = { "Digitalisate" => rd.int1, "ohne Digitalisate" => rd.int2-rd.int1 }

    # Art der Digitalisate
    @dc_anteile_digitalisate = @report.report_datum
      .where(legacy_name: "dc_anteile_digitalisate", int3: @report.id)
      .collect{|rd| [rd.string1, rd.int1]}
      .sort{|a, b| a[1] <=> b[1]}.reverse

    # Bilder: Nutzungsqualität
    @dc_bilder_qualitaet = @report.report_datum
      .where(legacy_name: "dc_bilder_qualitaet", int3: @report.id)
      .sort { |a, b| a.int2 <=> b.int2 }
      .collect { |rd| [rd.string1, rd.int1] }
  end

  # @action GET
  # @url /kennzahlen/:report_id/global
  #
  # Global data-sheet for a specific report.
  def global
    winston_title "Übersicht"

  end

  # @action GET
  # @url /kennzahlen/about
  def about
    winston_title "Erläuterungen"
  end

  # JSON interface for university location data + collection counts.
  def uni_coll_data
    mode = params[:page]
    data = Rails.cache.fetch("/winston/report/#{@report.id}-#{@report.updated_at}-#{mode}/uni_coll_data", :expires_in => 48.hours) do
      uni_coll_data_helper(mode)
    end
    render json: { status: "ok", data: data }
  end

  # @action GET
  # @url /kennzahlen/faecher
  def subjects
    winston_title "Fächer"

    @data = @report.report_datum.where(legacy_name: "anteile_fachgebiet").group("string1").select("string1","sum(report_data.int2) as 'int2'")


  end

  # @action GET
  # @url /kennzahlen/fluctuation
  def fluctuation
    winston_title "Fluktuation"

    fluctuation_hash = @report.report_datum.find_by(legacy_name: "collections_curatorship_fluctuation")
    @collections_won_curator = fluctuation_hash.int2
    @collections_lost_curator = fluctuation_hash.int3
    @collections_wonandlost_curator = fluctuation_hash.int4
    @total_collections = @report.report_datum.find_by(legacy_name: "absolut_sammlungen").int1

    @collections_won_curator_chartdata = {"Sammlungen mit Neuzugang": @collections_won_curator,"Andere": @total_collections - @collections_won_curator}
    @collections_lost_curator_chartdata = {"Sammlungen mit Abgang": @collections_lost_curator,"Andere": @total_collections - @collections_lost_curator}
    @collections_wonandlost_curator_chartdata = {"Sammlungen mit Wechsel": @collections_wonandlost_curator, "Andere": @total_collections - @collections_wonandlost_curator}
    
    curator_count_rd = @report.report_datum.find_by(legacy_name: "coll_curatorship_counting")
    @acc_curatorship_counting = [ 
      ["genau ein_e Ansprechpartner_in", curator_count_rd.int2], 
      ["mehrere Ansprechpartner_innen", curator_count_rd.int3],
      ["ohne Ansprechpartner_in", curator_count_rd.int1]
    ]
    
  end

  # @action GET
  # @url /kennzahlen/progress
  def progress
    winston_title "Entwicklung"

    @global = global_temporal_stats

    @globalprogress1 = @global.select{|hsh| %w(collection_count active_collection_count digitized_collection_count).collect{|str| I18n.t(str)}.include? hsh[:name]}
    @globalprogress2 = @global.select{|hsh| %w(object_portal_count webportal_count).collect{|str| I18n.t(str)}.include? hsh[:name]}

  end

  # @action GET
  # @url /kennzahlen/teaching
  def teaching
    winston_title "Lehre"

    @subject_academic_teaching_interdisciplinary = [{name: "Verwendung in der interdisziplinären Lehre", data: []},{name: "Keine Angabe", data:[]}]
    @subject_academic_teaching_basic = [{name: "Verwendung in der grundständigen Lehre", data: []},{name: "Keine Angabe", data:[]}]
    @coll_type_academic_teaching_interdisciplinary = [{name: "Verwendung in der interdisziplinären Lehre", data: [], stack: "inter"},{name: "Keine Angabe", data:[], stack: "inter", showInLegend: false}]
    @coll_type_academic_teaching_basic = [{name: "Verwendung in der grundständigen Lehre", data: [],stack: 'basic'},{name: "Keine Angabe", data:[], stack: "basic", showInLegend: false}]


    colls_with_subject = @report.report_datum.where(legacy_name: "sammlungen_mit_fach").reduce(Hash.new(0)) {|hash,rd| hash.update(rd.string1 => rd.int2)}
    colls_with_type =  @report.collection_type_counts
    

    @report.report_datum.where(legacy_name: "subject_academic_teaching",string1: "academic_teaching_interdisciplinary").each do |hash|
      subject = hash.string2
          @subject_academic_teaching_interdisciplinary[0][:data].push [subject, hash.int2]
          @subject_academic_teaching_interdisciplinary[1][:data].push [subject, colls_with_subject[subject] - hash.int2]
            #"not specified",@report.report_datum.where(legacy_name: "anteile_fachgebiet",string1: subject).first.int2]
        end

    @report.report_datum.where(legacy_name: "subject_academic_teaching",string1: "academic_teaching_basic").each do |hash|
      subject = hash.string2
          @subject_academic_teaching_basic[0][:data].push [subject, hash.int2]
          @subject_academic_teaching_basic[1][:data].push [subject, colls_with_subject[subject] - hash.int2]
        end



    @report.report_datum.where(legacy_name: "coll_type_academic_teaching",string1: "academic_teaching_basic")
      .where.not(string2: "keine Angabe").each do |hash|
        coll_type = hash.string2
        @coll_type_academic_teaching_basic[0][:data].push [coll_type, hash.int2]
        colls_with_type =  @report.collection_type_counts[coll_type] || 0
        @coll_type_academic_teaching_basic[1][:data].push [coll_type, colls_with_type - hash.int2]
    end
    @report.report_datum.where(legacy_name: "coll_type_academic_teaching",string1: "academic_teaching_interdisciplinary")
      .where.not(string2: "keine Angabe").each do |hash|
        coll_type = hash.string2
        @coll_type_academic_teaching_interdisciplinary[0][:data].push [coll_type, hash.int2]
        colls_with_type =  @report.collection_type_counts[coll_type] || 0
        @coll_type_academic_teaching_interdisciplinary[1][:data].push [coll_type, colls_with_type - hash.int2]
    end

    @subject_academic_teaching_interdisciplinary.reverse!
    @subject_academic_teaching_basic.reverse!
    @coll_type_academic_teaching_interdisciplinary.reverse!
    @coll_type_academic_teaching_basic.reverse!

    @coll_type_academic_teaching = @coll_type_academic_teaching_interdisciplinary + @coll_type_academic_teaching_basic

  end

  # @action GET
  # @url /kennzahlen/provenance
  def provenance
    winston_title "Provenienz"

    @subject_provenance = []
    @coll_type_provenance = []
    @documented_history_provenance = []

    @report.report_datum.where(legacy_name: "subject_provenance")
        .group_by(&:string1).each do |subject, datum_list|
          @subject_provenance.push ({
              name: subject,
              data: datum_list.collect{|hash| [hash.string2, hash.int2]}
            })
        end
    @report.report_datum.where(legacy_name: "coll_type_provenance").where.not(string2: "keine Angabe")
        .group_by(&:string1).each do |coll_type, datum_list|
          @coll_type_provenance.push ({
              name: coll_type,
              data: datum_list.collect{|hash| [hash.string2, hash.int2]}
            })
        end


    @report.report_datum.where(legacy_name: "documented_history_provenance")
        .group_by(&:string2).each do |doc_info, datum_list|
          @documented_history_provenance.push ({
              name: doc_info,
              data: datum_list.collect{|hash| [hash.string1, hash.int2]}
            })
        end
    
    @documented_history_provenance.push({
      name: "novalue",
      data: @report.report_datum.where(legacy_name:"total_provenance_info").collect do|hash| 
        docsum = @documented_history_provenance.collect{|hsh| hsh[:data]}.flatten(1).select{|lst| lst[0] == hash.string1}.collect{|lst| lst[1].to_i}.sum
        [hash.string1, hash.int2 - docsum]
      end
    })
        
    @subject_provenance.each {|hsh| hsh[:name] = I18n.t hsh[:name]}
    @coll_type_provenance.each {|hsh| hsh[:name] = I18n.t hsh[:name]}
    @documented_history_provenance.each {|hsh| hsh[:name] = I18n.t hsh[:name]}
    @documented_history_provenance.each{|hsh| hsh[:data].each {|list| list[0] = I18n.t list[0] }}
    
    @documented_history_provenance.reverse!

  end

  # @action GET
  # @url /kennzahlen/collectionhistory
  def collectionhistory
    winston_title "Sammlungsgeschichte"

    @subject_documented_history = []
    @coll_type_documented_history = []
    
    colls_with_subject = @report.report_datum.where(legacy_name: "sammlungen_mit_fach").reduce(Hash.new(0)) {|hash,rd| hash.update(rd.string1 => rd.int2)}
    colls_with_type =  @report.collection_type_counts
    
    
    # add "keine Angabe"
    @documentations_per_subject = @report.report_datum.where(legacy_name: "subject_documented_history").to_a.group_by(&:string2)
    @documentations_per_subject.each do |subject,datum_list|
      documented_colls_sum = datum_list.collect(&:int2).sum
      undocumented_colls_sum = colls_with_subject[subject] - documented_colls_sum
      datum_list.append({string1: "novalue", int2: undocumented_colls_sum, string2: subject})
    end
        
    # group for chart representation
    @documentations_per_subject.values.flatten.group_by{|rd| rd[:string1]}.each do |doc_info, datum_list|
          @subject_documented_history.push ({
              name: doc_info,
              data: datum_list.collect{|hash| [hash[:string2], hash[:int2]]}
            })
        end
        
        
        
    @documentations_per_colltype = @report.report_datum.where(legacy_name: "coll_type_documented_history")
      .where.not(string2: "keine Angabe").to_a.group_by(&:string2)
    @documentations_per_colltype.each do |coll_type,datum_list|
      documented_colls_sum = datum_list.collect(&:int2).sum
      undocumented_colls_sum = colls_with_type[coll_type] - documented_colls_sum
      datum_list.append({string1: "novalue", int2: undocumented_colls_sum, string2: coll_type})
    end
    
    @documentations_per_colltype.values.flatten.group_by{|rd| rd[:string1]}.each do |doc_info, datum_list|
      @coll_type_documented_history.push ({
          name: doc_info,
          data: datum_list.collect{|hash| [hash[:string2], hash[:int2]]}
        })
    end
    
    @coll_type_documented_history = @coll_type_documented_history.each {|hash| hash[:name] = I18n.t hash[:name]}
    @subject_documented_history = @subject_documented_history.each {|hash| hash[:name] = I18n.t hash[:name]}
    
    @subject_documented_history.reverse!
    @coll_type_documented_history.reverse!
    
  end
  
  # @action GET
  # @url /kennzahlen/budget
  def budget
    winston_title "Budget"
    
    @coll_type_budget = {name: "Budget vorhanden", data:[]},{name: "Kein Budget", data:[]},{name: "Keine Angabe", data:[]}
    colls_with_type = @report.collection_type_counts
    
    @report.report_datum.where(legacy_name: "coll_type_budget").where.not(string1: "Keine Angabe").each do |rd|
      @coll_type_budget[0][:data].push([rd.string1,rd.int2])
      @coll_type_budget[1][:data].push([rd.string1,rd.int3])
      
      # we do not distinguish between explicit and implicit N/A data
      no_info = colls_with_type[rd.string1] - rd.int3 - rd.int2
      @coll_type_budget[2][:data].push([rd.string1, no_info])
    end
    @coll_type_budget.reverse!
    
    
    rd = @report.report_datum.where(legacy_name: "total_budget").first
    @total_budget = {"Budget vorhanden" => rd.int2,"Kein Budget" => rd.int3, "Keine Angabe" => @report.collection_count - rd.int3 - rd.int2}
    
  end
  
  # @action GET
  # @url /kennzahlen/usage_regulation
  def usage_regulation
    winston_title "Benutzungsordnung"
    
    @coll_type_usage_regulation = {name: "Benutzungsordnung vorhanden", data:[]},{name: "Keine Benutzungsordnung", data:[]},{name: "Keine Angabe", data:[]}
    colls_with_type = @report.collection_type_counts
    
    @report.report_datum.where(legacy_name: "coll_type_usage_regulation").where.not(string1: "Keine Angabe").each do |rd|
      @coll_type_usage_regulation[0][:data].push([rd.string1,rd.int2])
      @coll_type_usage_regulation[1][:data].push([rd.string1,rd.int3])
      
      # we do not distinguish between explicit and implicit N/A data
      no_info = colls_with_type[rd.string1] - rd.int3 - rd.int2
      @coll_type_usage_regulation[2][:data].push([rd.string1, no_info])
    end
    @coll_type_usage_regulation.reverse!
    
    
    rd = @report.report_datum.where(legacy_name: "total_usage_regulation").first
    @total_usage_regulation = {"Benutzungsordnung vorhanden" => rd.int2,"Keine Benutzungsordnung" => rd.int3, "Keine Angabe" => @report.collection_count - rd.int3 - rd.int2}

  end
  
  # @action GET
  # @url /kennzahlen/collection_concept
  def collection_concept
    winston_title "Sammlungskonzept"

    @coll_type_collection_concept = {name: "Sammlungskonzept vorhanden", data:[], color: "3e5ca8"},{name: "Kein Sammlungskonzept", data:[], color: "1f2e54"},{name: "Keine Angabe", data:[], color: "d2daee"}
    colls_with_type = @report.collection_type_counts
    
    @report.report_datum.where(legacy_name: "coll_type_collection_concept").where.not(string1: "Keine Angabe").each do |rd|
      @coll_type_collection_concept[0][:data].push([rd.string1,rd.int2])
      @coll_type_collection_concept[1][:data].push([rd.string1,rd.int3])
      
      # we do not distinguish between explicit and implicit N/A data
      no_info = colls_with_type[rd.string1] - rd.int3 - rd.int2
      @coll_type_collection_concept[2][:data].push([rd.string1, no_info])
    end
    @coll_type_collection_concept.reverse!
    
    
    rd = @report.report_datum.where(legacy_name: "total_collection_concept").first
    @total_collection_concept = [["Sammlungskonzept vorhanden", rd.int2],["Kein Sammlungskonzept", rd.int3], ["Keine Angabe", @report.collection_count - rd.int3 - rd.int2]]
    

  end

  private

  def set_report
    if id = params[:report_id]
      @report = Report.find(id)
    elsif defined?(DEFAULT_REPORT_DATE)
      @report = Report.find_by(date: DEFAULT_REPORT_DATE)
    else
      @report = Report.order("date desc").take
    end

    if @report.nil? && params[:action] != "no_report_yet"
      redirect_to "/kennzahlen/no_report_yet"
    end

    # sets active state on "Kennzahlen" tab
    @menu_tab_kennzahlen_active = true
  end

  def winston_title title
    page_title "#{title} • #{"Kennzahlen zu wissenschaftlichen Sammlungen an deutschen Universitäten"}", replace: true
  end

  # @param string [String] A string whose Umlauts should be interpreted as vowels.
  #
  # @example
  #   deumlautify "Ägyptologie" -> "Agyptologie"
  #
  # @return [String] A string with Umlauts replaced with their respective vowel.
  def deumlautify string
    string.gsub(/[ÄÖÜ]/, {
      "Ä" => "A",
      "Ö" => "O",
      "Ü" => "U",
      "ä" => "a",
      "ö" => "o",
      "ü" => "u"
    })
  end

  # @param limit [Integer] The maximum size of the resulting array. If
  #   specified, the result will be ordered alphabetically. Otherwise the first
  #   'limit' entries of the Subjects with the highest number of linked
  #   SciCollections will be ordered descendingly by their share of SciCollections
  #   with DigitalCollections.
  #
  # @example
  #   # in view
  #   bar_chart dc_anteile_fachgebiet(30)
  #
  # @return [Array<Hash>] An array with data about the distribution of digital
  #   collections within each subject. The output format can be directly fed into
  #   chartkick.
  def dc_anteile_fachgebiet limit=nil, order="relative"
    dcaf = @report.report_datum.where(legacy_name: "dc_anteile_fachgebiet")

    if limit
      # choose the most "relevant" Subjects, saved in int2
      dcaf = dcaf.order(int2: :desc).first(limit)
    end

    dcaf = dcaf.collect{|rd| [ rd.string1, rd.int1, rd.int2-rd.int1, rd.float1]}

    if limit
      # sort descendingly by digitalisation share
      if order=="relative"
        dcaf = dcaf.sort{|a, b| a[3] <=> b[3]}.reverse
      else
        dcaf = dcaf.sort{|a, b| a[1] <=> b[1]}.reverse
      end
    else
      # sort alphabetically
      dcaf = dcaf.sort do |a, b|
        deumlautify(a[0]) <=> deumlautify(b[0])
      end
    end
    dcafinv = dcaf.collect{|v| [v[0], v[2]]}
    [
      {
        name: "nicht digital zugänglich",
        data: dcafinv
      },
      {
        name: "digital zugänglich",
        data: dcaf
      }
    ]
  end

  # Set site-wide Chartkick options, all options below 'library' aimed at
  # Highcharts- directly, API-Documentation: http://api.highcharts.com/highcharts
  def set_chart_options
    case params["action"]
    when "global"
      Chartkick.options = {
        height: "400",
        spacing: [0,0,0,0],
        margin: [0,0,0,0],
        # demonstration of deep-options use
        library: {
          plotOptions: {
            pie: {
              borderWidth: 0,
              dataLabels: {
                format: "{point.name} ({point.percentage:.1f} %)",
                style: {
                  fontWeight: "normal",
                  fontSize: "14px"
                }
              },
              tooltip: {
                valueSuffix: " Sammlung(en)",
              }
            },
            bar: {
              color: "#505d81",
              tooltip: {
                valuePrefix: "",
                valueSuffix: " Aktivität(en)"
              }
            }
          },
          tooltip: {
            useHTML: true,
            valuePrefix: "{point.name}: ",
            headerFormat: "",
            pointFormat: "{point.y}",
          }
        }
      }
    when "states"
      # set states-site-wide Chartkick options
      Chartkick.options = {
        height: "75px",
        spacing: [0,0,0,0],
        margin: [0,0,0,0],
        library: {
          colors: ["#1f2e54", "#d2daee"],
          plotOptions: {
            pie: {
              dataLabels: {
                enabled: false
              },
              enableMouseTracking: false, # disable hover behaviour
              borderWidth: 0
            }
          },
          chart: {
            height: "75",
            width: "75",
            spacing: [0,0,0,0],
            margin: [0,0,0,0]
          },
          tooltip: {
            enabled: false,
            useHTML: true
          }
        }
      }
    when "digital_collections"
      Chartkick.options = {
        height: "400",
        spacing: [0,0,0,0],
        margin: [0,0,0,0],
        library: {
          plotOptions: {
            pie: {
              borderWidth: 0,
              dataLabels: {
                format: "{point.name} ({point.percentage:.1f} %)",
                style: {
                  fontWeight: "normal",
                  fontSize: "14px"
                }
              },
              tooltip: {
                valueSuffix: " Sammlung(en)",
              }
            },
            bar: {
              tooltip: {
                valuePrefix: "",
                valueSuffix: " Sammlung(en)"
              }
            }
          },
          tooltip: {
            useHTML: true,
            valuePrefix: "{point.name}: ",
            headerFormat: "",
            pointFormat: "{point.y}",
          },
          # bar chart options
          xAxis: {
            # font style for left-side labels of bar charts
            labels: {
              style: {
                fontSize: "14px",
              }
            }
          },
          yAxis: {
            allowDecimals: false,
            tickInterval: 25,
          },
        }
      }
    when "university"
      Chartkick.options = {
        library: {
          plotOptions: {
            pie: {
              borderWidth: 0,
              size: 250,
              dataLabels: {
                enabled: false
              },
              showInLegend: false,
              # disable legend-click-triggered pie resize-animation
              point: {
                events: {
                  legendItemClick: "event.preventDefault()"
                }
              }
            }
          },
          chart: {
            height: "300",
            width: "300",
            spacing: [0,0,0,0],
            margin: [0,0,0,0]
          },
          tooltip: {
            useHTML: true,
            valuePrefix: "{point.name}: ",
            valueSuffix: " Sammlung(en)",
            headerFormat: "",
            pointFormat: "{point.y}"
          },
        }
      }
    when "collectionhistory"
      Chartkick.options = {
        height: "400",
        spacing: [0,0,0,0],
        margin: [0,0,0,0],
        library: {
          plotOptions: {
            pie: {
              borderWidth: 0,
              dataLabels: {
                format: "{point.name} ({point.percentage:.1f} %)",
                style: {
                  fontWeight: "normal",
                  fontSize: "14px"
                }
              },
              tooltip: {
                valueSuffix: " Sammlung(en)",
              }
            },
            bar: {
              tooltip: {
                valuePrefix: "",
                valueSuffix: " Sammlung(en)"
              }
            }
          },
          tooltip: {
            useHTML: true,
            valuePrefix: "{point.name}: ",
            headerFormat: "",
            pointFormat: "{point.y}",
          },
          # bar chart options
          xAxis: {
            # font style for left-side labels of bar charts
            labels: {
              style: {
                fontSize: "14px",
              }
            }
          },
          yAxis: {
            allowDecimals: false,
            tickInterval: 25,
          },
        }
      }
    when "progress"
      Chartkick.options = {
        height: "400",
        spacing: [0,0,0,0],
        margin: [0,0,0,0],
        # demonstration of deep-options use
        library: {
          plotOptions: {
            series: {
              lineWidth: 5,
              marker: {
                radius: 10
              }
            }
          },
          tooltip: {
            useHTML: true,
            valuePrefix: "{point.series.name}: ",
            headerFormat: "",
            pointFormat: "{point.y}",
            valueSuffix: " ({point.x:%d.%m.%Y})"
          }
        }
      }
    when "fluctuation"
      Chartkick.options = {
        height: "200px",
        spacing: [0,0,0,0],
        margin: [0,0,0,0],
        library: {
          #colors: ["#1f2e54","#d2daee","#4566ba","3e5ca8"],#["#1f2e54","#d2daee"],
          charts: {
            backgroundColor: 'rgba(255, 255, 255, 0.0)',
          },
          plotOptions: {
            pie: {
              borderWidth: 0,
              dataLabels: {
                format: "{point.name} ({point.percentage:.1f} %)",
                style: {
                  fontWeight: "normal",
                  fontSize: "14px"
                }
              },
              tooltip: {
                valueSuffix: " Sammlung(en)",
              }
            }
          },
          tooltip: {
            useHTML: true,
            valuePrefix: "{point.name}: ",
            headerFormat: "",
            pointFormat: "{point.y}",
          }
        }
      }
    when "provanance"
      Chartkick.options = {
        height: "400",
        spacing: [0,0,0,0],
        margin: [0,0,0,0],
        library: {
          plotOptions: {
            bar: {
              tooltip: {
                valuePrefix: "",
                valueSuffix: " Sammlung(en)"
              }
            }
          },
          tooltip: {
            useHTML: true,
            valuePrefix: "{point.name}: ",
            headerFormat: "",
            pointFormat: "{point.y}",
          },
          # bar chart options
          xAxis: {
            # font style for left-side labels of bar charts
            labels: {
              style: {
                fontSize: "14px",
              }
            }
          },
          yAxis: {
            allowDecimals: false,
            tickInterval: 25,
          },
        }
      }
    when "teaching"
      Chartkick.options = {
        height: "400",
        spacing: [0,0,0,0],
        margin: [0,0,0,0],
        library: {
          plotOptions: {
            bar: {
              tooltip: {
                valuePrefix: "",
                valueSuffix: " Sammlung(en)"
              }
            }
          },
          tooltip: {
            useHTML: true,
            valuePrefix: "{point.name}: ",
            headerFormat: "",
            pointFormat: "{point.y}",
          },
          # bar chart options
          xAxis: {
            # font style for left-side labels of bar charts
            labels: {
              style: {
                fontSize: "14px",
              }
            }
          },
          yAxis: {
            allowDecimals: false,
            tickInterval: 25,
          },
        }
      }
    else
      Chartkick.options = {
        height: "400",
        spacing: [0,0,0,0],
        margin: [0,0,0,0],
        library: {
          plotOptions: {
            pie: {
              borderWidth: 0,
              dataLabels: {
                format: "{point.name} ({point.percentage:.1f} %)",
                style: {
                  fontWeight: "normal",
                  fontSize: "14px"
                }
              },
              tooltip: {
                valueSuffix: " Sammlung(en)",
              }
            },
            bar: {
              tooltip: {
                valuePrefix: "",
                valueSuffix: " Sammlung(en)"
              }
            }
          },
          tooltip: {
            useHTML: true,
            valuePrefix: "{point.name}: ",
            headerFormat: "",
            pointFormat: "{point.y}",
          },
          # bar chart options
          xAxis: {
            # font style for left-side labels of bar charts
            labels: {
              style: {
                fontSize: "14px",
              }
            }
          },
          yAxis: {
            allowDecimals: false,
            tickInterval: 25,
          },
        }
      }
    end
  end

  def uni_coll_data_helper mode
    if mode == "subjects"
      keys = %w(
        lat lon
        name maya_id
        coll_count coll_subjects
      )
    else
      # Gather values that are used in JavaScript
      keys = %w(
        lat lon
        name maya_id
        coll_count has_coll_coord has_coll_policy has_coll_website has_object_portal
      )
    end
    universities = @report.universities
    data = universities.map do |uni|
      keys.each_with_object({}) do |field, hash|
        begin
          hash[field] = uni.send(field)
        rescue
          Rails.logger.error("No #{field} for uni #{uni.maya_id}")
        end
      end
    end
  end

  def global_temporal_stats
    @reports = Report.all

    @states = []
    WinstonState.all.group_by(&:name).each do |state_label, states|
      stateHash = {
        university_count: {},
        collection_count: {},
        active_collection_count: {},
        collection_coordination_count: {},
        collection_policy_count: {},
        digitized_collection_count: {},
        webportal_count: {},
        object_portal_count: {}
      }

      stateHash.keys.each do |prop|
        states = states.select {|state| state.send(prop)}
        stateHash[prop] = states.collect{|state| [state.report.date.to_s,state.send(prop)]}

      end
      stateHash[:name] = state_label
      @states << stateHash
    end

    keys = %w(collection_count active_collection_count digitized_collection_count object_portal_count collection_coordination_count webportal_count)

    @global = keys.collect{|key| {name: key, data: {}}}

    @states.each do |stateHash|
      keys.each do |key|
        stateHash[key.to_sym].each do |date,value|
          data = @global.select{|hsh| hsh[:name]==key}.first[:data]
          if data[date]
            data[date] += value
          else
            data[date] = value
          end
        end
      end
    end

    # localize @global
    @global.each do |h|
      h[:name] = I18n.t(h[:name])
    end
    @global

  end

  def scientific_funtion_numbers
    rolelist = SciCollection.all.includes(:role).collect{|coll| coll.safe_values("role")}
    distribution = Hash.new(0)
    rolelist.each do |roles|
      roles.each{ | v | distribution.store(v, distribution[v]+1) }
    end

    colls_without_roles = rolelist.select{|roles| roles.blank?}.count
    colls_with_roles = rolelist.select{|roles| !roles.blank?}.count


    [distribution, {"Sammlungen mit Funktion": colls_with_roles, "Sammlungen ohne Funktion": colls_without_roles}]
  end

  def museums_and_collections
    museum_org_type = OrganisationType.find_by label: "Museum"
    museums = Organisation.all.select{|org| org.organisation_type.collect{|type| type.objekt_id}.include? museum_org_type.id}

    collections_with_special_form_museum = SciCollection.all.select{|col| col.special_form.collect{|spform| spform.objekt_id }.include? museum_org_type.id}

    collections_with_special_form_having_parts = collections_with_special_form_museum.select{|col| col.has_part}

    sum_collections_with_special_form_and_parts = collections_with_special_form_having_parts.collect{|col| col.all_partial_collections_and_self}.flatten.uniq


    museums_keeping = museums.select{|org| org.current_keeper}

    colls_kept_by_museums = museums_keeping.collect{|museum| museum.current_keeper.collect{|prop| prop.objekt.all_partial_collections_and_self}}.flatten.uniq

    h = {
      "Museen": museums.count,
      "Museen, die Sammlungen betreuen": museums_keeping.count,
      "Anzahl an von Museen betreueten Sammlungen": colls_kept_by_museums.count,
      "Sammlungen, die Museen sind":  collections_with_special_form_museum.count,
      "Sammlungen, die Museen sind und Teilsammlungen haben": collections_with_special_form_having_parts.count,
      "Sammlungen, die Museen sind und ihre Teilsammlungen": sum_collections_with_special_form_and_parts.count
    }
    h
  end

end
