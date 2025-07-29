class CreateSources < ActiveRecord::Migration[8.0]
  def change
    create_table :sources do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.timestamps
    end

    add_index :sources, :code, unique: true
  end
end
