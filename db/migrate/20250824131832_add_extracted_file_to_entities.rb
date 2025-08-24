class AddExtractedFileToEntities < ActiveRecord::Migration[8.0]
  def change
    add_reference :entities, :extracted_file, null: true, foreign_key: { on_delete: :cascade }
  end
end
