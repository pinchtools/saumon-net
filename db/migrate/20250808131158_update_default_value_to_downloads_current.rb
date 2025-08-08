class UpdateDefaultValueToDownloadsCurrent < ActiveRecord::Migration[8.0]
  def change
    change_column_default :downloads, :current, from: nil, to: false
  end
end
