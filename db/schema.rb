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

ActiveRecord::Schema[8.1].define(version: 2025_11_06_102132) do
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

  create_table "gitlab_assignees", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email"
    t.bigint "external_id", null: false
    t.datetime "last_synced_at"
    t.string "name"
    t.string "state"
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["external_id"], name: "index_gitlab_assignees_on_external_id", unique: true
    t.index ["name"], name: "index_gitlab_assignees_on_name"
    t.index ["username"], name: "index_gitlab_assignees_on_username"
  end

  create_table "gitlab_commit_diffs", force: :cascade do |t|
    t.string "a_mode"
    t.string "b_mode"
    t.bigint "commit_id", null: false
    t.datetime "created_at", null: false
    t.boolean "deleted_file", default: false, null: false
    t.text "diff_text"
    t.boolean "new_file", default: false, null: false
    t.string "new_path"
    t.string "old_path"
    t.jsonb "raw_payload", default: {}, null: false
    t.boolean "renamed_file", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["commit_id", "new_path"], name: "index_commit_diffs_on_commit_and_new_path"
    t.index ["commit_id"], name: "index_gitlab_commit_diffs_on_commit_id"
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

  create_table "gitlab_issue_assignees", force: :cascade do |t|
    t.bigint "assignee_id", null: false
    t.datetime "created_at", null: false
    t.bigint "issue_id", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_gitlab_issue_assignees_on_assignee_id"
    t.index ["issue_id", "assignee_id"], name: "index_issue_assignees_on_issue_and_assignee", unique: true
    t.index ["issue_id"], name: "index_gitlab_issue_assignees_on_issue_id"
  end

  create_table "gitlab_issue_labels", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "issue_id", null: false
    t.bigint "label_id", null: false
    t.datetime "updated_at", null: false
    t.index ["issue_id", "label_id"], name: "index_issue_labels_on_issue_and_label", unique: true
    t.index ["issue_id"], name: "index_gitlab_issue_labels_on_issue_id"
    t.index ["label_id"], name: "index_gitlab_issue_labels_on_label_id"
  end

  create_table "gitlab_issues", force: :cascade do |t|
    t.string "assignee_name"
    t.string "author_name"
    t.string "category_name"
    t.datetime "closed_on"
    t.string "complexity"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "external_id", null: false
    t.integer "fixed_version_id"
    t.string "fixed_version_name"
    t.string "follow_up_on"
    t.integer "gitlab_issue_iid"
    t.string "gitlab_issue_project_path"
    t.string "gitlab_issue_web_url"
    t.datetime "gitlab_last_synced_at"
    t.string "gitlab_sync_checksum"
    t.string "priority"
    t.string "project_identifier", null: false
    t.text "release_notes"
    t.boolean "release_notes_publish"
    t.string "status"
    t.string "title", null: false
    t.string "tracker"
    t.datetime "updated_at", null: false
    t.datetime "updated_on"
    t.string "valid_for"
    t.index ["external_id"], name: "index_gitlab_issues_on_external_id", unique: true
    t.index ["gitlab_issue_project_path", "gitlab_issue_iid"], name: "idx_on_gitlab_issue_project_path_gitlab_issue_iid_d2e16d3175", unique: true, where: "(gitlab_issue_iid IS NOT NULL)"
    t.index ["project_identifier", "status"], name: "index_gitlab_issues_on_project_identifier_and_status"
  end

  create_table "gitlab_labels", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "external_id", null: false
    t.string "name", null: false
    t.string "project_path", null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.string "text_color"
    t.datetime "updated_at", null: false
    t.index ["project_path", "external_id"], name: "index_gitlab_labels_on_project_path_and_external_id", unique: true
    t.index ["project_path", "name"], name: "index_gitlab_labels_on_project_path_and_name"
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

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "sync_schedules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "last_error"
    t.datetime "last_run_at"
    t.datetime "last_success_at"
    t.jsonb "metadata", default: {}, null: false
    t.string "scope"
    t.string "task_name", null: false
    t.datetime "updated_at", null: false
    t.index ["task_name", "scope"], name: "index_sync_schedules_on_task_name_and_scope", unique: true
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

  add_foreign_key "gitlab_commit_diffs", "gitlab_commits", column: "commit_id"
  add_foreign_key "gitlab_issue_assignees", "gitlab_assignees", column: "assignee_id"
  add_foreign_key "gitlab_issue_assignees", "gitlab_issues", column: "issue_id"
  add_foreign_key "gitlab_issue_labels", "gitlab_issues", column: "issue_id"
  add_foreign_key "gitlab_issue_labels", "gitlab_labels", column: "label_id"
  add_foreign_key "llm_requests", "requests"
  add_foreign_key "request_message_parts", "requests"
  add_foreign_key "request_variables", "requests"
  add_foreign_key "requests", "conversations"
  add_foreign_key "response_entries", "requests"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
