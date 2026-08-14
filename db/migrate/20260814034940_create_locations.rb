class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      # What the spot provides, as distinct from what a plant wants (that lives
      # on Plant#light_requirement). A location with a grow light counts as one
      # step brighter — see Location#effective_light.
      t.string :natural_light, null: false, default: "medium"
      t.string :exposure
      t.string :grow_light_entity_id

      t.text :notes

      t.timestamps
    end

    add_index :locations, :name, unique: true
    add_index :locations, :position
  end
end
