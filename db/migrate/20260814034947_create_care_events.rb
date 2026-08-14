class CreateCareEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :care_events do |t|
      t.references :pot, null: false, foreign_key: true

      # watered / fertilized / repotted / treated / pruned. One table rather than
      # five near-identical ones: they share a shape (pot, date, note) and this
      # gives each pot a single timeline for free.
      t.string :kind, null: false

      t.date :occurred_on, null: false
      t.string :product
      t.text :note

      t.timestamps
    end

    add_index :care_events, [ :pot_id, :kind, :occurred_on ]
  end
end
