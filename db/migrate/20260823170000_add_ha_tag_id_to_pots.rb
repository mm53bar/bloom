class AddHaTagIdToPots < ActiveRecord::Migration[8.1]
  def change
    add_column :pots, :ha_tag_id, :string
    add_index :pots, :ha_tag_id, unique: true
  end
end
