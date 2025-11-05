# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_11_04_194512) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "attachments", force: :cascade do |t|
    t.bigint "attachable_id"
    t.string "attachable_type"
    t.string "checksum"
    t.datetime "created_at", null: false
    t.binary "data"
    t.string "file_name"
    t.integer "file_size"
    t.string "file_type"
    t.string "source_uri"
    t.datetime "updated_at", null: false
    t.index ["attachable_type", "attachable_id"], name: "index_attachments_on_attachable"
  end

  create_table "conversations", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "initial_location"
    t.jsonb "metadata", default: {}, null: false
    t.jsonb "requester_avatar_uri", default: {}, null: false
    t.string "requester_username", null: false
    t.jsonb "responder_avatar_uri", default: {}, null: false
    t.string "responder_username"
    t.text "summary"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_conversations_on_external_id", unique: true
  end

  create_table "embeddings", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.vector "embedding", limit: 384, null: false
    t.jsonb "metadata", default: {}, null: false
    t.float "similarity"
    t.bigint "source_id", null: false
    t.string "source_type", null: false
    t.datetime "updated_at", null: false
    t.index ["source_type", "source_id"], name: "index_embeddings_on_source"
  end

  create_table "gitlab_commit_diffs", force: :cascade do |t|
    t.string "a_mode"
    t.string "b_mode"
    t.datetime "created_at", null: false
    t.boolean "deleted_file", default: false, null: false
    t.text "diff_text"
    t.bigint "gitlab_commit_id", null: false
    t.boolean "new_file", default: false, null: false
    t.string "new_path"
    t.string "old_path"
    t.jsonb "raw_payload", default: {}, null: false
    t.boolean "renamed_file", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["gitlab_commit_id", "new_path"], name: "index_commit_diffs_on_commit_and_new_path"
    t.index ["gitlab_commit_id"], name: "index_gitlab_commit_diffs_on_gitlab_commit_id"
  end

  create_table "gitlab_commits", force: :cascade do |t|
    t.string "author_email"
    t.string "author_name"
    t.datetime "committed_at"
    t.datetime "created_at", null: false
    t.text "message"
    t.string "project_path", null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.string "sha", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "web_url"
    t.index ["project_path", "committed_at"], name: "index_gitlab_commits_on_project_path_and_committed_at"
    t.index ["sha"], name: "index_gitlab_commits_on_sha", unique: true
  end

  create_table "issues", force: :cascade do |t|
    t.string "assignee_name"
    t.string "author_name"
    t.datetime "closed_on"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "external_id", null: false
    t.string "priority"
    t.string "project_identifier", null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.string "status"
    t.string "title", null: false
    t.string "tracker"
    t.datetime "updated_at", null: false
    t.datetime "updated_on"
    t.index ["external_id"], name: "index_issues_on_external_id", unique: true
    t.index ["project_identifier", "status"], name: "index_issues_on_project_identifier_and_status"
  end

  create_table "llm_requests", force: :cascade do |t|
    t.integer "completion_tokens"
    t.datetime "created_at", null: false
    t.integer "latency_ms"
    t.string "model", null: false
    t.integer "prompt_tokens"
    t.string "provider"
    t.bigint "request_id", null: false
    t.jsonb "request_payload", default: {}, null: false
    t.jsonb "response_payload", default: {}, null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["model", "created_at"], name: "index_llm_requests_on_model_and_created_at"
    t.index ["request_id"], name: "index_llm_requests_on_request_id"
  end

  create_table "request_message_parts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "editor_range_payload", default: {}, null: false
    t.string "kind", null: false
    t.integer "position", null: false
    t.jsonb "range_payload", default: {}, null: false
    t.bigint "request_id", null: false
    t.text "text"
    t.datetime "updated_at", null: false
    t.index ["request_id", "position"], name: "index_message_parts_on_request_and_position"
    t.index ["request_id"], name: "index_request_message_parts_on_request_id"
  end

  create_table "request_variables", force: :cascade do |t|
    t.boolean "automatically_added", default: false, null: false
    t.datetime "created_at", null: false
    t.string "external_id"
    t.boolean "is_root", default: false, null: false
    t.string "kind"
    t.text "model_description"
    t.string "name"
    t.string "origin_label"
    t.bigint "request_id", null: false
    t.datetime "updated_at", null: false
    t.jsonb "value", default: {}, null: false
    t.index ["request_id", "external_id"], name: "index_variables_on_request_and_external"
    t.index ["request_id"], name: "index_request_variables_on_request_id"
  end

  create_table "requests", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.jsonb "message_payload", default: {}, null: false
    t.text "message_text"
    t.string "model"
    t.integer "position"
    t.string "response_external_id"
    t.jsonb "result_payload", default: {}, null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.jsonb "variable_payload", default: {}, null: false
    t.index ["conversation_id", "created_at"], name: "index_requests_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_requests_on_conversation_id"
    t.index ["external_id"], name: "index_requests_on_external_id", unique: true
  end

  create_table "response_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.jsonb "payload", default: {}, null: false
    t.integer "position", null: false
    t.bigint "request_id", null: false
    t.text "text_value"
    t.datetime "updated_at", null: false
    t.index ["request_id", "position"], name: "index_response_entries_on_request_id_and_position"
    t.index ["request_id"], name: "index_response_entries_on_request_id"
  end

  create_table "wiki_pages", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "project_identifier", null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.string "slug", null: false
    t.text "summary"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.datetime "updated_on"
    t.index ["external_id"], name: "index_wiki_pages_on_external_id", unique: true
    t.index ["project_identifier", "slug"], name: "index_wiki_pages_on_project_identifier_and_slug", unique: true
  end

  add_foreign_key "gitlab_commit_diffs", "gitlab_commits"
  add_foreign_key "llm_requests", "requests"
  add_foreign_key "request_message_parts", "requests"
  add_foreign_key "request_variables", "requests"
  add_foreign_key "requests", "conversations"
  add_foreign_key "response_entries", "requests"
end
