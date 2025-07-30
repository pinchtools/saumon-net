class CreateEntities < ActiveRecord::Migration[8.0]
  def change
    create_table :entities do |t|
      t.string :uid, null: false
      t.string :type, null: false
      t.jsonb :metadata
      t.references :download
      t.timestamps
    end

    add_index :entities, :uid, unique: true
    add_index :entities, :type
    add_index :entities, :metadata, using: :gin
  end
end
