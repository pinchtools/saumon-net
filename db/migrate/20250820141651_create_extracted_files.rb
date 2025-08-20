class CreateExtractedFiles < ActiveRecord::Migration[8.0]
  def change
    create_table :extracted_files do |t|
      t.string :path, null: false
      t.references :download
      t.timestamps
    end

    add_index :extracted_files, [ :path, :download_id ], unique: true
  end
end
