class RemoveChecksumFromDownloads < ActiveRecord::Migration[8.0]
  def change
    remove_column :downloads, :checksum, :string, null: false
  end
end
