class FirstTables < ActiveRecord::Migration[8.1]
  def change

    create_table :conversations do |t|
      t.string :external_id, null: false
      t.string :requester_username, null: false
      t.jsonb :requester_avatar_uri, default: {}, null: false
      t.string :responder_username
      t.jsonb :responder_avatar_uri, default: {}, null: false
      t.string :initial_location
      t.string :title
      t.text :summary
      t.text :content
      t.jsonb :metadata, default: {}, null: false
      t.timestamps
    end
    add_index :conversations, :external_id, unique: true

    create_table :requests do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :external_id, null: false
      t.string :response_external_id
      t.text :message_text
      t.jsonb :message_payload, default: {}, null: false
      t.jsonb :variable_payload, default: {}, null: false
      t.jsonb :result_payload, default: {}, null: false
      t.string :model
      t.string :status
      t.integer :position
      t.timestamps
    end
    add_index :requests, :external_id, unique: true
    add_index :requests, [:conversation_id, :created_at]

    create_table :request_message_parts do |t|
      t.references :request, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :kind, null: false
      t.text :text
      t.jsonb :range_payload, default: {}, null: false
      t.jsonb :editor_range_payload, default: {}, null: false
      t.timestamps
    end
    add_index :request_message_parts, [:request_id, :position], name: "index_message_parts_on_request_and_position"

    create_table :request_variables do |t|
      t.references :request, null: false, foreign_key: true
      t.string :external_id
      t.string :name
      t.string :kind
      t.text :model_description
      t.boolean :is_root, default: false, null: false
      t.boolean :automatically_added, default: false, null: false
      t.string :origin_label
      t.jsonb :value, default: {}, null: false
      t.timestamps
    end
    add_index :request_variables, [:request_id, :external_id], name: "index_variables_on_request_and_external"

    create_table :response_entries do |t|
      t.references :request, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :kind, null: false
      t.text :text_value
      t.jsonb :payload, default: {}, null: false
      t.timestamps
    end
    add_index :response_entries, [:request_id, :position]

    create_table :llm_requests do |t|
      t.references :request, null: false, foreign_key: true
      t.string :model, null: false
      t.string :provider
      t.integer :prompt_tokens
      t.integer :completion_tokens
      t.integer :latency_ms
      t.string :status
      t.jsonb :request_payload, default: {}, null: false
      t.jsonb :response_payload, default: {}, null: false
      t.timestamps
    end
    add_index :llm_requests, [:model, :created_at]

    create_table :attachments do |t|
      t.string :file_name
      t.string :file_type
      t.integer :file_size
      t.string :checksum
      t.string :source_uri
      t.binary :data
      t.references :attachable, polymorphic: true, index: true
      t.timestamps
    end

    create_table :issues do |t|
      t.string :external_id, null: false
      t.string :project_identifier, null: false
      t.string :tracker
      t.string :status
      t.string :priority
      t.string :title, null: false
      t.text :description
      t.string :assignee_name
      t.string :author_name
      t.datetime :closed_on
      t.datetime :updated_on
      t.jsonb :raw_payload, default: {}, null: false
      t.timestamps
    end
    add_index :issues, :external_id, unique: true
    add_index :issues, [:project_identifier, :status]

    create_table :wiki_pages do |t|
      t.string :external_id, null: false
      t.string :project_identifier, null: false
      t.string :title, null: false
      t.string :slug, null: false
      t.text :summary
      t.text :content
      t.datetime :updated_on
      t.jsonb :raw_payload, default: {}, null: false
      t.timestamps
    end
    add_index :wiki_pages, :external_id, unique: true
    add_index :wiki_pages, [:project_identifier, :slug], unique: true

    create_table :gitlab_commits do |t|
      t.string :sha, null: false
      t.string :project_path, null: false
      t.string :title, null: false
      t.text :message
      t.string :author_name
      t.string :author_email
      t.datetime :committed_at
      t.string :web_url
      t.jsonb :raw_payload, default: {}, null: false
      t.timestamps
    end
    add_index :gitlab_commits, :sha, unique: true
    add_index :gitlab_commits, [:project_path, :committed_at]

    create_table :gitlab_commit_diffs do |t|
      t.references :gitlab_commit, null: false, foreign_key: true
      t.string :old_path
      t.string :new_path
      t.boolean :new_file, default: false, null: false
      t.boolean :renamed_file, default: false, null: false
      t.boolean :deleted_file, default: false, null: false
      t.string :a_mode
      t.string :b_mode
      t.text :diff_text
      t.jsonb :raw_payload, default: {}, null: false
      t.timestamps
    end
    add_index :gitlab_commit_diffs, [:gitlab_commit_id, :new_path], name: "index_commit_diffs_on_commit_and_new_path"

  end
end
