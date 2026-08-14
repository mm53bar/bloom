class CreateMoistureReadings < ActiveRecord::Migration[8.1]
  def change
    create_table :moisture_readings do |t|
      t.references :pot, null: false, foreign_key: true

      # Percentage, as reported by the probe. Kept separate from CareEvent: this
      # is a machine-generated measurement, not something a person did.
      t.decimal :value, precision: 5, scale: 2, null: false

      t.datetime :read_at, null: false
      t.string :source, null: false, default: "manual"

      t.timestamps
    end

    add_index :moisture_readings, [ :pot_id, :read_at ]
  end
end
