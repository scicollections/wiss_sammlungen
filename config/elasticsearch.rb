# Elasticsearch Index Configuration

ESConfig = OpenStruct.new(
  connection: (YAML.load(ERB.new(File.read(Rails.root.join("config", "elasticsearch.yml"))).result)[Rails.env] rescue {}),

  index_settings: {
    index: {
      number_of_shards: 1,
      number_of_replicas: 0
    },
    analysis: {
      filter: {
        substring: {
          type: "ngram",
          min_gram: 2,
          max_gram: 30
        },
        anti_diacritics: {
          type: "asciifolding",
          preserve_original: true
        },
        german_collation: {
          type: "icu_collation",
          language: "de",
          country: "DE"
        }
      },
      analyzer: {
        default: {
          type: "custom",
          tokenizer: "standard",
          filter: [
            "lowercase",
            "german_normalization",
            "anti_diacritics",
            "substring"
          ]
        },
        default_search: {
          type: "custom",
          tokenizer: "standard",
          filter: [
            "lowercase",
            "german_normalization",
            "anti_diacritics"
          ]
        },
        sort_analyzer: {
          type: "custom",
          tokenizer: "keyword",
          filter: [
            "german_collation"
          ]
        }
      }
    }
  },

  mappings: {
    individual: {
      dynamic_templates: [
        {
          facet_terms: {
            path_match: "facet.*",
            mapping: {
              type: "keyword",
              index: "true",
              fields: {
                search: {
                  type: "text",
                  index: "true"
                }
              }
            }
          }
        }
      ],
      properties: {

        # General data fields

        id: {
          type: "integer"
        },
        klass: {
          type: "keyword",
          index: "true"
        },
        scope: {
          # AKA Visibility
          type: "keyword",
          index: "true"
        },
        related_ids: {
          # Individuals, which are possibly affected by changes
          # Used for updating the index
          type: "integer"
        },
        label: {
          type: "text",
          index: "true",
          fields: {
            sort: {
              type: "text",
              index: "true",
              analyzer: "sort_analyzer"
            }
          }
        },
        inline_label: {
          type: "text",
          index: "true",
          fields: {
            sort: {
              type: "text",
              index: "true",
              fielddata: true,
              analyzer: "sort_analyzer"
            }
          }
        },
        thumb: {
          # Thumbnail ID for SciCollectionObjects
          type: "integer"
        },


        # Discover specific data fields

        category: {
          type: "keyword",
          index: "true"
        },
        headline: {
          type: "text",
          index: "true",
          fields: {
            sort: {
              type: "text",
              fielddata: true,
              index: "true",
              analyzer: "sort_analyzer"
            }
          }
        },
        subheadline: {
          type: "text",
          index: "true",
        },
        description: {
          type: "text",
          index: "true",
        },
        hidden: {
          type: "text",
          index: "true",
        },
        same_as: {
          type: "keyword",
          index: "true"
        },


        # Other data

        facet: {
          type: "object"
        },
        
        # Survey data
        
        survey_states: {
          type: "nested"
        }
        
      }
    }
  },

  categories: {
    collection: "Sammlungen",
    digital: "Digitale Sammlungen",
    actor: "Akteure",
    activity: "Aktivitäten"
  },

  facets: {
    # Can't use underscores in facet names because they are used in CSS ids and the JavaScript
    # splits the ids by "_" and expects there to be no underscores in what it splits.
    activitytype: "Art der Aktivität",
    organisationtype: "Art der Einrichtung",
    subject: "Fachgebiet",
    genre: "Objektgattung",
    livingbeing: "Lebewesen",
    collection: "Sammlung",
    person: "Person",
    organisation: "Einrichtung",
    place: "Ort",
    reproduction: "Digitalisate",
    collectiontype: "Sammlungsart",
    collectionrole: "Wissenschaftliche Funktion",
    state: "Bundesland",
    vocab: "Externes Vokabular"
  },

  restrictions: {
    #activitytype: [:activity],
    #collection: [:digital, :actor, :activity],
    #reproduction: [:digital, :collection],
    #collectiontype: [:digital, :collection],
    #collectionrole: [:digital, :collection]
  }
)
