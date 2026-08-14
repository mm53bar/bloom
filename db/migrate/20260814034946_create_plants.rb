class CreatePlants < ActiveRecord::Migration[8.1]
  def change
    create_table :plants do |t|
      # Most pots hold exactly one plant. A shared container (a succulent bowl,
      # say) holds several that share one soil volume, one probe reading and one
      # watering decision — which is why readings and care hang off Pot, not here.
      t.references :pot, null: false, foreign_key: true

      t.string :name, null: false
      t.string :species

      # What this plant wants, against what its location provides.
      t.string :light_requirement, null: false, default: "medium"

      # Free-form pointer to care notes kept elsewhere — a wiki, a blog, a shop
      # listing. Deliberately generic: this app doesn't own that knowledge.
      t.string :reference_url

      t.date :acquired_on
      t.text :notes

      t.timestamps
    end
  end
end
