# A single `Location` conflated two things that behave differently: the part of a
# home a person names ("the living room"), and the particular place a pot sits
# ("the shelf by the window"). Light belongs to the second — a shelf in a south
# window and a shelf on the opposite wall of the same room provide completely
# different light — while names, grouping and the Home Assistant mapping belong
# to the first.
#
# See docs/adr/20260814-areas-and-spots.md.
class SplitLocationsIntoAreasAndSpots < ActiveRecord::Migration[8.1]
  def up
    create_table :areas do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      # Home Assistant calls this level an "area" too, which is why the model
      # borrows the word: the mapping is a pairing, not a translation.
      t.string :ha_area

      t.text :notes

      t.timestamps
    end

    add_index :areas, :name, unique: true
    add_index :areas, :position

    rename_table :locations, :spots
    add_reference :spots, :area, foreign_key: true

    # Every existing location becomes an area containing one spot of the same
    # name, which is the shape a single-spot area has anyway.
    execute <<~SQL.squish
      INSERT INTO areas (name, position, notes, created_at, updated_at)
      SELECT name, position, notes, created_at, updated_at FROM spots
    SQL
    execute <<~SQL.squish
      UPDATE spots SET area_id = (SELECT areas.id FROM areas WHERE areas.name = spots.name)
    SQL
    change_column_null :spots, :area_id, false

    # A spot name only has to be unique inside its area.
    remove_index :spots, column: :name
    remove_index :spots, column: :position
    add_index :spots, [ :area_id, :name ], unique: true
    add_index :spots, [ :area_id, :position ]

    rename_column :pots, :location_id, :spot_id
  end

  def down
    rename_column :pots, :spot_id, :location_id

    remove_index :spots, column: [ :area_id, :name ]
    remove_index :spots, column: [ :area_id, :position ]
    remove_reference :spots, :area, foreign_key: true
    rename_table :spots, :locations
    add_index :locations, :name, unique: true
    add_index :locations, :position

    drop_table :areas
  end
end
