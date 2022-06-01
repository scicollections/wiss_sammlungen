# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2022_01_19_140511) do

  create_table "api_cache", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "api"
    t.string "authority_file"
    t.string "authority_id"
    t.text "data_json"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["api", "authority_file", "authority_id"], name: "index_api_cache_on_api_and_authority_file_and_authority_id", unique: true
  end

  create_table "individuals", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "type"
    t.string "label"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "inline_label"
    t.string "descriptive_id"
    t.string "visible_for_cache"
    t.text "info_text_cache"
    t.integer "isus_id", default: 0
    t.string "isus_type"
    t.integer "crm_id", default: 0
    t.string "isil_id"
    t.string "psearch2"
    t.string "psearch3", limit: 10000
    t.string "importbatch"
    t.boolean "dirty", default: false
    t.string "thumb"
    t.integer "sequence", default: 0
    t.index ["descriptive_id"], name: "index_individuals_on_descriptive_id", unique: true
  end

  create_table "properties", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "subject_id"
    t.string "predicate", limit: 50
    t.integer "objekt_id"
    t.string "data", limit: 500
    t.text "data_text"
    t.integer "data_int"
    t.float "data_float"
    t.boolean "data_bool"
    t.date "data_date"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "type"
    t.index ["created_at"], name: "index_properties_on_created_at"
    t.index ["data"], name: "index_properties_on_data", length: 255
    t.index ["data_bool"], name: "index_properties_on_data_bool"
    t.index ["data_date"], name: "index_properties_on_data_date"
    t.index ["data_float"], name: "index_properties_on_data_float"
    t.index ["data_int"], name: "index_properties_on_data_int"
    t.index ["objekt_id"], name: "index_properties_on_objekt_id"
    t.index ["predicate", "data_bool"], name: "index_properties_on_predicate_and_data_bool"
    t.index ["subject_id", "predicate"], name: "index_properties_on_subject_id_and_predicate"
    t.index ["subject_id"], name: "index_properties_on_subject_id"
    t.index ["updated_at"], name: "index_properties_on_updated_at"
  end

  create_table "report_data", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "report_id"
    t.string "legacy_name"
    t.string "type"
    t.integer "int1"
    t.integer "int2"
    t.integer "int3"
    t.integer "int4"
    t.integer "int5"
    t.integer "int6"
    t.integer "int7"
    t.integer "int8"
    t.integer "int9"
    t.integer "int10"
    t.string "string1"
    t.string "string2"
    t.string "string3"
    t.string "string4"
    t.string "string5"
    t.string "string6"
    t.string "string7"
    t.string "string8"
    t.string "string9"
    t.string "string10"
    t.string "string11"
    t.string "string12"
    t.string "string13"
    t.string "string14"
    t.string "string15"
    t.boolean "bool1"
    t.boolean "bool2"
    t.boolean "bool3"
    t.boolean "bool4"
    t.boolean "bool5"
    t.boolean "bool6"
    t.boolean "bool7"
    t.boolean "bool8"
    t.boolean "bool9"
    t.boolean "bool10"
    t.text "text1"
    t.text "text2"
    t.text "text3"
    t.text "text4"
    t.text "text5"
    t.float "float1"
    t.float "float2"
    t.float "float3"
    t.float "float4"
    t.float "float5"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "reports", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.date "date"
    t.boolean "locked", default: false, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "revisions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "user_id"
    t.integer "property_id"
    t.string "property_type"
    t.integer "subject_id"
    t.string "subject_label"
    t.string "subject_type"
    t.string "predicate", limit: 50
    t.integer "old_objekt_id"
    t.integer "new_objekt_id"
    t.string "old_objekt_label"
    t.string "new_objekt_label"
    t.string "old_objekt_type"
    t.string "new_objekt_type"
    t.string "old_objekt_last_visibility_before_deletion"
    t.string "new_objekt_last_visibility_before_deletion"
    t.string "old_data", limit: 500
    t.string "new_data", limit: 500
    t.text "old_data_text"
    t.text "new_data_text"
    t.integer "old_data_int"
    t.integer "new_data_int"
    t.float "old_data_float"
    t.float "new_data_float"
    t.boolean "old_data_bool"
    t.boolean "new_data_bool"
    t.date "old_data_date"
    t.date "new_data_date"
    t.string "action"
    t.string "creator_role"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "old_individual_id"
    t.integer "new_individual_id"
    t.string "individual_type"
    t.string "old_label"
    t.string "new_label"
    t.boolean "hide_on_global_list", default: false
    t.boolean "inverse", default: false
    t.integer "occured_at_related_strong_individual_id"
    t.string "occured_at_related_strong_individual_type"
    t.string "occured_at_related_strong_individual_label"
    t.string "occured_at_related_strong_individual_predicate"
    t.integer "other_related_strong_individual_id"
    t.string "other_related_strong_individual_type"
    t.string "other_related_strong_individual_label"
    t.string "other_related_strong_individual_predicate"
    t.integer "complex_property_parent_individual_id"
    t.string "complex_property_parent_individual_type"
    t.string "complex_property_parent_individual_label"
    t.string "complex_property_parent_individual_predicate"
    t.boolean "indexed"
    t.string "campaign_slug"
  end

  create_table "search_logs", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "sid"
    t.string "cat_filter"
    t.string "query"
    t.text "facet_filter"
    t.integer "hits"
    t.text "url"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["facet_filter"], name: "facet_filter", length: 12
    t.index ["query"], name: "query"
  end

  create_table "sessions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["created_at"], name: "created_at"
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "user_events", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "action"
    t.string "campaign_slug"
    t.text "text"
    t.integer "individual_id"
    t.string "individual_label"
    t.string "individual_type"
    t.string "type", null: false
    t.integer "target_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "indexed", default: false
    t.index ["individual_id"], name: "index_user_events_on_individual_id"
    t.index ["target_user_id"], name: "index_user_events_on_target_user_id"
    t.index ["user_id"], name: "index_user_events_on_user_id"
  end

  create_table "users", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.string "first_name"
    t.string "email"
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "role", default: ""
    t.integer "individual_id"
    t.string "invited_by"
    t.string "invitation_to"
    t.string "invitation_from"
    t.string "invitation_subject"
    t.datetime "invitation_date"
    t.text "invitation_mail"
    t.boolean "clicked_invitation_link", default: false
    t.string "survey_token"
    t.text "survey_invitation_mail"
    t.datetime "survey_invitation_date"
    t.string "rss_token"
    t.string "api_key"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "user_events", "users"
  add_foreign_key "user_events", "users", column: "target_user_id"
end
