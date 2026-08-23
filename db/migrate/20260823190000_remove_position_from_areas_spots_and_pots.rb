class RemovePositionFromAreasSpotsAndPots < ActiveRecord::Migration[8.1]
  def change
    remove_column :areas, :position, :integer, default: 0, null: false
    remove_column :spots, :position, :integer, default: 0, null: false
    remove_column :pots, :position, :integer, default: 0, null: false
  end
end
