class CreateDownloads < ActiveRecord::Migration[8.0]
  def change
    create_table :downloads do |t|
      t.string :fingerprint, null: false
      t.string :checksum, null: false
      t.string :name, null: false
      t.boolean :current, null: false
      t.integer :version, default: 1, null: false
      t.references :source
      t.timestamps
    end

    add_index :downloads, [ :fingerprint, :version ], unique: true
    add_index :downloads, :name
    add_index :downloads, :fingerprint,
              unique: true,
              where: "current = true",
              name: "index_downloads_on_fingerprint_where_current_true"
  end
end
