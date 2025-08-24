class AddForeignKeyOnDownloadEntities < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :entities, :downloads, on_delete: :cascade
  end
end
