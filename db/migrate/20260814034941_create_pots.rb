class CreatePots < ActiveRecord::Migration[8.1]
  def change
    create_table :pots do |t|
      t.references :location, null: false, foreign_key: true
      t.string :name, null: false

      # Alternate spoken names, for voice assistants matching a pot by ear.
      t.json :voice_aliases, null: false, default: []

      # Soil and semi-hydro are different care regimes, not the same regime with
      # different numbers: watering, what a probe reading means, and how feeding
      # works all diverge. See Pot#needs_water? and #needs_fertilizer?.
      t.string :medium, null: false, default: "soil"

      # Probe thresholds, as percentages. Only meaningful for soil pots.
      t.integer :dry_below, null: false, default: 20
      t.integer :wet_above, null: false, default: 100

      # Fallbacks used when no reading is available, and the check cadence that
      # decides when a pot is stale enough to be worth walking to.
      t.integer :water_interval_days
      t.integer :fertilize_interval_days
      t.integer :check_interval_days, null: false, default: 7

      t.integer :position, null: false, default: 0
      t.date :potted_on
      t.text :notes

      t.timestamps
    end

    add_index :pots, [ :location_id, :position ]
  end
end
