require "pgvector/pg"
class AddEmbeds < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector" unless extension_enabled?("vector")

    create_table :embeddings do |t|
      t.references :source, polymorphic: true, null: false, index: true
      t.vector :embedding, limit: 384, null: false
      t.text :content
      t.float :similarity
      t.jsonb :metadata, default: {}, null: false
      t.timestamps
    end
  end
end
