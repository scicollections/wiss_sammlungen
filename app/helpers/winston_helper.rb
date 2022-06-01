module WinstonHelper
  # Digests the given collection-type(s) and returns the corresponding color(s).
  #
  # @overload get_colors(type)
  #   @param type [String] The collection type.
  #   @return [String] The color.
  #
  # @overload get_colors(types)
  #   @param types [Array<String>] The collection types.
  #   @return [Array<String>] The colors.
  def get_colors types
    if types.kind_of?(Array)
      types.collect do |type|
        COLOR_MAP[type]
      end
    else
      COLOR_MAP[types]
    end
  end

  # Renders the @anteile_akt_sam data in global view.
  def chart_global_anteile_akt_sam
    pie_chart(
      @report.collection_status_counts,
      colors: ["#efefef", "#1f2e54", "#d2daee"],
      library: {
        plotOptions: {
          pie: {
            borderWidth: 0
          }
        }
      }
    )
  end

  # Renders the @anteile_sammlungsart data in global view.
  def chart_global_anteile_sammlungsart
    pie_chart(
      @report.collection_type_counts,
      colors: get_colors(@report.collection_type_counts.keys)
    )
  end

  # Renders the "Aktive Sammlungen"-data in a states view's row.
  def chart_states_aktive_sammlungen(state)
    pie_chart([
      [
        "aktiv",
        state.active_collection_count
      ],
      [
        "nicht aktiv",
        state.collection_count - state.active_collection_count
      ]
    ]) if state.active_collection_count
  end

  # Renders the "digital zugängliche Sammlungen"-data in a states view's row.
  def chart_states_digitale_sammlungen(state)
    pie_chart([
      [
        "digital zugängliche Sammlungen",
        state.digitized_collection_count
      ],
      [
        "nicht digital zugängliche Sammlungen",
        state.collection_count - state.digitized_collection_count
      ]
    ]) if state.digitized_collection_count
  end

  # Renders the "Universitäten mit Sammlunskoordination"-data in a states
  # view's row.
  def chart_states_collection_coordinations(state)
    pie_chart([
      [
        "Universitäten mit Sammlungskoordination",
        state.collection_coordination_count
      ],
      [
        "Universitäten ohne Sammlungskoordination",
        state.university_count - state.collection_coordination_count
      ]
    ]) if state.collection_coordination_count
  end

  # Renders the "Universitäten mit Sammlunsordnung"-data in a states
  # view's row.
  def chart_states_collection_policies(state)
    pie_chart([
      [
        "Universitäten mit Sammlungsordnung",
        state.collection_policy_count
      ],
      [
        "Universitäten ohne Sammlungsordnung",
        state.university_count - state.collection_policy_count
      ]
    ]) if state.collection_policy_count
  end

  # Renders the "Universitäten mit Sammlungsportal"-data in a states
  # view's row.
  def chart_states_collection_webportals(state)
    pie_chart([
      [
        "Universitäten mit Sammlungsportal",
        state.webportal_count
      ], [
        "Universitäten ohne Sammlungsportal",
        state.university_count - state.webportal_count
      ]
    ]) if state.webportal_count
  end

  # Renders the "Aktive Sammlung"-data for a single university in a states
  # view's row.
  def chart_states_university_aktive_sammlung(uni)
    pie_chart(
      [
        [
          "aktiv",
          uni.active_coll_share
        ],
        [
          "nicht aktiv",
          uni.coll_count - uni.active_coll_share
        ]
      ],
      colors: %w(#1f2e54 #d2daee)
    ) if uni.active_coll_share
  end

  # Renders the "digital zugänglich"-data for a single university in a states
  # view's row.
  def chart_states_university_digitale_sammlungen(uni)
    pie_chart(
      [
        [
          "digital zugänglich",
          uni.digital_coll_share
        ],
        [
          "nicht digital zugänglich",
          uni.coll_count - uni.digital_coll_share
        ]
      ],
      colors: %w(#1f2e54 #d2daee)
    ) if uni.digital_coll_share
  end

  # Renders the @dc_anteile_sammlungen data in digital collections view.
  def chart_digital_collections_anteile_sammlungen
    pie_chart(
      @dc_anteile_sammlungen,
      colors: %w(#1f2e54 #d2daee)
    )
  end

  # Renders the @dc_anteile_sammlungsart data in digital collections view.
  def chart_digital_collections_anteile_sammlungsart
    bar_chart(
      @dc_anteile_sammlungsart,
      stacked: true,
      colors: %w(#d2daee #1f2e54),
      library: {
        tooltip: {
          pointFormat: '<span style="color:{series.color}">'\
            '&#x2588;</span> {series.name}: <b>{point.y}</b> '\
            '({point.percentage:.0f}%)<br/>',
          shared: true
        },
        yAxis: {
          max: @dc_anteile_sammlungsart_max_value
        },
        legend: {
          reversed: true
        }
      }
    )
  end

  # Renders the @dc_anteile_fachgebiet data in digital collections view.
  def chart_digital_collections_anteile_fachgebiet relative=true

    data = relative ? @dc_anteile_fachgebiet : @dc_anteile_fachgebiet_abs
    bar_chart(
      data,
      colors: %w(#d2daee #1f2e54),
      height: "800px",
      library: {
        tooltip: {
          pointFormat: '<span style="color:{series.color}">'\
            '&#x2588;</span> {series.name}: <b>{point.y}</b> '\
            '({point.percentage:.0f}%)<br/>',
          shared: true
        },
        plotOptions: {
          series: {
            #stacking: 'normal'
            stacking: relative ? 'percent' : 'normal'
          }
        },
        yAxis: {
          allowDecimals: false,
          tickInterval: 10,
          labels: {
            format: relative ? "{value}%" : "{value}"
          }
        },
        legend: {
          reversed: true
        }
      }
    )
  end

  # Renders the @dc_digitalisate data in digital collections view.
  def chart_digital_collections_digitalisate
    pie_chart(
      @dc_digitalisate,
      colors: %w(#1f2e54 #d2daee),
      library: {
        plotOptions: {
          pie: {
            tooltip: {
              valueSuffix: " digitale Sammlung(en)"
            }
          }
        }
      }
    )
  end

  # Renders the @dc_anteile_digitalisate data in digital collections view.
  def chart_digital_collections_anteile_digitalisate
    bar_chart(
      @dc_anteile_digitalisate,
      colors: %w(#b92101 #4a924c #fead08 #5890a6 #f2ead0 #cbddf2 #e6e6e6
        #e6e6e6),
      library: {
        plotOptions: {
          bar: {
            colorByPoint: true,
            tooltip: {
              valueSuffix: " digitale Sammlung(en)"
            }
          }
        }
      }
    )
  end

  # Renders the @dc_bilder_qualitaet data in digital collections view.
  def chart_digital_collections_bilder_qualitaet
    pie_chart(
      @dc_bilder_qualitaet,
      colors: %w(#EFEFEF #9CAACE #6D7CA4 #485882 #1F2E54),
      library: {
        plotOptions: {
          pie: {
            tooltip: {
              valueSuffix: " digitale Sammlung(en)"
            }
          }
        }
      }
    )
  end

  # Renders the @dc_anteile_fachgebiet_full data in digital collections view.
  def chart_digital_collections_anteile_fachgebiet_full data, relative=true
    bar_chart(
      data,
      colors: %w(#d2daee #1f2e54),
      height: "2900px",
      library: {
        tooltip: {
          pointFormat: '<span style="color:{series.color}">'\
            '&#x2588;</span> {series.name}: <b>{point.y}</b> '\
            '({point.percentage:.0f}%)<br/>',
          shared: true
        },
        plotOptions: {
          series: {
            stacking: relative ? 'percent' : 'normal'
          }
        },
        yAxis: {
          opposite: true,
          allowDecimals: false,
          tickInterval: 10,
          labels: {
            format: relative ? "{value}%" : "{value}"
          }
        },
        chart: {
          marginRight: 50
        },
        legend: {
          reversed: true,
          verticalAlign: "top"
        }
      }
    )
  end

  # Renders the @uni.coll_type_shares data in university view.
  def chart_university_anteile_sammlungsart
    pie_chart(
      @uni.coll_type_shares,
      colors: get_colors(@uni.coll_type_shares.keys),
      id:"pie-chart"
    )
  end
  
  
  # stacking values: "percent" "normal" false
  def bar_chart_library_settings stacking: false, showPercentages: true, shared: true
    pointFormat = '<span style="color:{series.color}">'\
          '&#x2588;</span> {series.name}: <b>{point.y}</b> '
    if showPercentages
      pointFormat += '({point.percentage:.0f}%)<br/>'
    else
      pointFormat += '<br/>'
    end 
    
    {
      tooltip: {
        pointFormat: pointFormat,
        shared: shared
      },
      plotOptions: {
        series: {
          stacking: stacking
        }
      },
      yAxis: {
        opposite: true,
        allowDecimals: false,
        tickInterval: 10,
        labels: {
          format: stacking == "percent" ? "{value}%" : "{value}"
        }
      },
      chart: {
        marginRight: 50
      },
      legend: {
        reversed: true,
        verticalAlign: "top"
      }
    }
  end

  # Map collection types to colors.
  COLOR_MAP = {
    "Ethnologie & Kulturanthropologie"=>"#cbddf2",
    "Geschichte & Archäologie"=>"#f2ead0",
    "Kulturgeschichte & Kunst"=>"#fead08",
    "Medizin"=>"#b92101",
    "Naturgeschichte/Naturkunde"=>"#4a924c",
    "Naturwissenschaft & Technik"=>"#5890a6",
    "keine Angabe"=>"#ba7ec6",
    nil=>"#e6e6e6"
  }

  # Map university IDs to coordinates on the map. They can differ from the real coordinates to look
  # better on the map.
  UNI_COORDS = {
    # Charité – Universitätsmedizin Berlin
    294=>{
      "lat"=>"52.65",
      "lon"=>"13.43"
    },
    # Universität Heidelberg
    313=>{
      "lat"=>"49.4077",
      "lon"=>"8.69079"
    },
    # Martin-Luther-Universität Halle-Wittenberg
    831=>{
      "lat"=>"51.46",
      "lon"=>"11.99"
    },
    # Freie Universität Berlin
    345=>{
      "lat"=>"52.43",
      "lon"=>"13.22"
    },
    # Universität Bremen
    1870=>{
      "lat"=>"53.14",
      "lon"=>"8.87"
    },
    # Friedrich-Alexander-Universität Erlangen-Nürnberg
    484=>{
      "lat"=>"49.591",
      "lon"=>"11.0078"
    },
    # Albert-Ludwigs-Universität Freiburg
    471=>{
      "lat"=>"47.9935",
      "lon"=>"7.846"
    },
    # Georg-August-Universität Göttingen
    446=>{
      "lat"=>"51.513",
      "lon"=>"9.95353"
    },
    # Rheinisch-Westfälische Technische Hochschule Aachen
    521=>{
      "lat"=>"50.7766",
      "lon"=>"6.08342"
    },
    # Universität Stuttgart
    544=>{
      "lat"=>"48.7767",
      "lon"=>"9.1775"
    },
    # Universität Erfurt
    561=>{
      "lat"=>"50.9787",
      "lon"=>"11.0328"
    },
    # Technische Universität Dresden
    582=>{
      "lat"=>"51.02",
      "lon"=>"13.72"
    },
    # Friedrich-Schiller-Universität Jena
    605=>{
      "lat"=>"50.9326",
      "lon"=>"11.5868"
    },
    # Technische Universität Berlin
    651=>{
      "lat"=>"52.61",
      "lon"=>"13.2"
    },
    # Humboldt-Universität zu Berlin
    657=>{
      "lat"=>"52.49",
      "lon"=>"13.55"
    },
    # Eberhard Karls Universität Tübingen
    674=>{
      "lat"=>"48.5227",
      "lon"=>"9.05222"
    },
    # Johannes Gutenberg-Universität Mainz
    718=>{
      "lat"=>"49.92",
      "lon"=>"8.1"
    },
    # Rheinische Friedrich-Wilhelms-Universität Bonn
    742=>{
      "lat"=>"50.7336",
      "lon"=>"7.10334"
    },
    # Universität Bielefeld
    765=>{
      "lat"=>"52.0333",
      "lon"=>"8.53333"
    },
    # Westfälische Wilhelms-Universität Münster
    768=>{
      "lat"=>"51.94",
      "lon"=>"7.63"
    },
    # Technische Universität München
    813=>{
      "lat"=>"48.25",
      "lon"=>"11.45"
    },
    # Universität Bamberg
    821=>{
      "lat"=>"49.8934",
      "lon"=>"10.8912"
    },
    # Bauhaus-Universität Weimar
    891=>{
      "lat"=>"50.9803",
      "lon"=>"11.329"
    },
    # Technische Universität Dortmund
    895=>{
      "lat"=>"51.5125",
      "lon"=>"7.47695"
    },
    # Technische Universität Darmstadt
    919=>{
      "lat"=>"49.8717",
      "lon"=>"8.65027"
    },
    # Universität Paderborn
    925=>{
      "lat"=>"51.7077",
      "lon"=>"8.77223"
    },
    # Universität Duisburg-Essen
    4192=>{
      "lat"=>"51.5",
      "lon"=>"7.00588"
    },
    # Universität der Künste Berlin
    6583=>{
      "lat"=>"52.52",
      "lon"=>"13.34"
    },
    # Zeppelin Universität
    73399=>{
      "lat"=>"47.6587",
      "lon"=>"9.43395"
    },
    # Hochschule für Bildende Künste Dresden
    953=>{
      "lat"=>"51.1",
      "lon"=>"13.89"
    },
    # Jacobs University Bremen gGmbH
    1015=>{
      "lat"=>"53.167",
      "lon"=>"8.65181"
    },
    # Universität Bayreuth
    1019=>{
      "lat"=>"49.9478",
      "lon"=>"11.5789"
    },
    # Technische Universität Bergakademie Freiberg
    373=>{
      "lat"=>"50.9109",
      "lon"=>"13.3388"
    },
    # Universität Rostock
    1145=>{
      "lat"=>"54.0887",
      "lon"=>"12.1405"
    },
    # Universität Hamburg
    1051=>{
      "lat"=>"53.5753",
      "lon"=>"10.0153"
    },
    # Philipps-Universität Marburg
    1094=>{
      "lat"=>"50.8107",
      "lon"=>"8.77419"
    },
    # Universität zu Köln
    1123=>{
      "lat"=>"50.9239",
      "lon"=>"6.9201"
    },
    # Stiftung Tierärztliche Hochschule Hannover
    5053=>{
      "lat"=>"52.27",
      "lon"=>"9.81"
    },
    # Universität Osnabrück
    1176=>{
      "lat"=>"52.2738",
      "lon"=>"8.05213"
    },
    # Stiftung Universität Hildesheim
    1181=>{
      "lat"=>"52.1508",
      "lon"=>"9.95112"
    },
    # Julius-Maximilians-Universität Würzburg
    1379=>{
      "lat"=>"49.7971",
      "lon"=>"9.93365"
    },
    # Universität Augsburg
    1860=>{
      "lat"=>"48.3715",
      "lon"=>"10.8985"
    },
    # Katholische Universität Eichstätt-Ingolstadt
    2155=>{
      "lat"=>"48.8885",
      "lon"=>"11.1967"
    },
    # Universität Leipzig
    2405=>{
      "lat"=>"51.3396",
      "lon"=>"12.3713"
    },
    # Justus-Liebig-Universität Gießen
    2452=>{
      "lat"=>"50.5873",
      "lon"=>"8.67554"
    },
    # Universität Trier
    2497=>{
      "lat"=>"49.7556",
      "lon"=>"6.63935"
    },
    # Ruhr-Universität Bochum
    2909=>{
      "lat"=>"51.4803",
      "lon"=>"7.21828"
    },
    # Technische Universität Clausthal
    3031=>{
      "lat"=>"51.8095",
      "lon"=>"10.3382"
    },
    # Johann Wolfgang Goethe-Universität Frankfurt
    3048=>{
      "lat"=>"50.1247",
      "lon"=>"8.66777"
    },
    # Christian-Albrechts-Universität zu Kiel
    3233=>{
      "lat"=>"54.3213",
      "lon"=>"10.1349"
    },
    # Universität Regensburg
    3283=>{
      "lat"=>"49.0168",
      "lon"=>"12.0954"
    },
    # Ernst-Moritz-Arndt-Universität Greifswald
    3323=>{
      "lat"=>"54.0931",
      "lon"=>"13.3879"
    },
    # Universität Hohenheim
    3602=>{
      "lat"=>"48.69",
      "lon"=>"9.27"
    },
    # Technische Universität Carolo-Wilhelmina zu Braunschweig
    4045=>{
      "lat"=>"52.2659",
      "lon"=>"10.5267"
    },
    # Universität Karlsruhe (TH)
    4068=>{
      "lat"=>"49.01",
      "lon"=>"8.48"
    },
    # Universität des Saarlandes
    4080=>{
      "lat"=>"49.2354",
      "lon"=>"6.98165"
    },
    # Heinrich-Heine-Universität Düsseldorf
    860=>{
      "lat"=>"51.17",
      "lon"=>"6.81"
    },
    # Carl von Ossietzky-Universität Oldenburg
    4237=>{
      "lat"=>"53.1412",
      "lon"=>"8.21467"
    },
    # Universität Potsdam
    4255=>{
      "lat"=>"52.401",
      "lon"=>"13.0111"
    },
    # Universität  Kassel
    4329=>{
      "lat"=>"51.3167",
      "lon"=>"9.5"
    },
    # Ludwig-Maximilians-Universität München
    4345=>{
      "lat"=>"48.15",
      "lon"=>"11.58"
    },
    # Universität Ulm
    4399=>{
      "lat"=>"48.3984",
      "lon"=>"9.95"
    },
    # Universität Konstanz
    4522=>{
      "lat"=>"47.71",
      "lon"=>"9.17582"
    },
    # Gottfried Wilhelm Leibniz Universität Hannover
    4545=>{
      "lat"=>"52.3829",
      "lon"=>"9.71"
    },
    # Universität Vechta
    4579=>{
      "lat"=>"52.7263",
      "lon"=>"8.28598"
    },
    # Medizinische Hochschule Hannover
    5234=>{
      "lat"=>"52.384",
      "lon"=>"9.83"
    },
    # Otto-von-Guericke-Universität Magdeburg
    5309=>{
      "lat"=>"52.1277",
      "lon"=>"11.6292"
    },
    # Musikhochschule Lübeck
    5805=>{
      "lat"=>"53.89",
      "lon"=>"10.6873"
    },
    # Technische Universität Kaiserslautern
    6074=>{
      "lat"=>"49.443",
      "lon"=>"7.77161"
    },
    # Staatliche Akademie der Künste Karlsruhe
    6441=>{
      "lat"=>"49.01",
      "lon"=>"8.31"
    },
    # Kunstakademie Düsseldorf
    6551=>{
      "lat"=>"51.27",
      "lon"=>"6.75"
    },
    # Burg Giebichenstein Hochschule für Kunst und Design Halle
    781=>{
      "lat"=>"51.56",
      "lon"=>"11.82"
    },
    # Philosophisch-Theologische Hochschule SVD St. Augustin
    6622=>{
      "lat"=>"50.83",
      "lon"=>"7.3"
    },
    # Kunstakademie Münster Hochschule für Bildende Künste
    6670=>{
      "lat"=>"52.05",
      "lon"=>"7.5"
    },
    # Folkwang Universität für Musik
    6679=>{
      "lat"=>"51.388209",
      "lon"=>"7.004541"
    },
    # Staatliche Akademie der Bildenden Künste Stuttgart
    6720=>{
      "lat"=>"48.89",
      "lon"=>"9.175"
    },
    # Akademie der Bildenden Künste München
    6819=>{
      "lat"=>"48.28",
      "lon"=>"11.6"
    },
    # Technische Universität Ilmenau
    6862=>{
      "lat"=>"50.6832",
      "lon"=>"10.9186"
    },
    # Bergische Universität Wuppertal
    7000=>{
      "lat"=>"51.2718",
      "lon"=>"7.20399"
    },
    # Deutsche Sporthochschule Köln
    7108=>{
      "lat"=>"51",
      "lon"=>"6.75"
    },
    # Technische Universität Chemnitz
    7349=>{
      "lat"=>"50.8351",
      "lon"=>"12.9222"
    },
    # Hochschule für Künste Bremen
    7502=>{
      "lat"=>"53.09",
      "lon"=>"8.76"
    },
    # Universität Passau
    24935=>{
      "lat"=>"48.5665",
      "lon"=>"13.4312"
    },
    # Universität der Bundeswehr München
    7779=>{
      "lat"=>"48.02",
      "lon"=>"11.63"
    },
    # Universität Siegen
    7885=>{
      "lat"=>"50.8734",
      "lon"=>"8.01042"
    },
    # Europa-Universität Viadrina, Frankfurt (Oder)
    177612=>{
      "lat"=>"52.3422",
      "lon"=>"14.5540"
    },
    # Universität zu Lübeck
    177632=>{
      "lat"=>"53.81",
      "lon"=>"10.71"
    },
    # Europa-Universität Flensburg
    180225=>{
      "lat"=>"54.776649",
      "lon"=>"9.458774"
    },
    # Universität Koblenz-Landau
    180315=>{
      "lat"=>"50.02",
      "lon"=>"8.2"
    },
    # Universität Mannheim
    181050=>{
      "lat"=>"49.483681",
      "lon"=>"8.5"
    },
    # Brandenburgische Technische Universität Cottbus-Senftenberg
    182247=>{
      "lat" => "51.76",
      "lon" => "14.32"
    },
    # Fernuniversität Hagen
    191289=>{
      "lat" => "51.36",
      "lon" => "7.51"
    },
  }
end
