# The qualitative light ladder — none / low / medium / bright / direct — cannot
# represent what measuring a real house turned up. Two shelves on the same unit,
# both with no natural light and both under a grow light, delivered 1.5 and 11.3
# mol/m²/day. The model called them both "low", because a grow light was worth
# exactly one step whatever it actually emitted.
#
# Daily light integral is the unit horticulture already uses for this, and unlike
# a word it can be measured. See docs/adr/20260817-light-as-dli.md.
class MeasureLightAsDli < ActiveRecord::Migration[8.1]
  def change
    change_table :spots, bulk: true do |t|
      # The authoritative figure: total light delivered over a day. Either
      # PPFD x hours for a spot on a timer, or an integrated curve for daylight.
      t.decimal :measured_dli, precision: 6, scale: 2

      # Supporting evidence, so a figure can be checked rather than trusted.
      t.decimal :measured_ppfd, precision: 8, scale: 1
      t.decimal :light_hours, precision: 4, scale: 1
      t.date :measured_at
    end

    # Overrides the default implied by light_requirement. Nil means "use the
    # default for this plant's qualitative requirement".
    add_column :plants, :dli_minimum, :decimal, precision: 6, scale: 2
  end
end
