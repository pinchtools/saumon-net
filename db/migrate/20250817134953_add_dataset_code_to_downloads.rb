class AddDatasetCodeToDownloads < ActiveRecord::Migration[8.0]
  def change
    add_column :downloads, :dataset_code, :string, null: false
  end
end
