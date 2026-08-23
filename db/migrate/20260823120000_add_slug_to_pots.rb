# Word banks are duplicated between here and Pot rather than shared, on
# purpose: a migration has to keep working after the model it once matched has
# moved on. See docs/adr/20260823-pot-slug-identifiers.md.
class AddSlugToPots < ActiveRecord::Migration[8.1]
  # Sourced entirely from the BIP39 English wordlist: common, short, and
  # deliberately chosen (unique 4-letter prefixes) to survive being misheard
  # or half-typed. See docs/adr/20260823-pot-slug-identifiers.md.
  ADJECTIVES = %w[
    copper velvet brisk hollow humble ancient arctic eternal digital happy
    heavy lazy lonely lucky magic oval pretty royal rural shy
    silent silly tiny busy casual curious dynamic elegant electric acoustic
  ].freeze

  NOUNS = %w[
    harbor canyon ridge valley hill island coast cliff mountain drift
    anchor ladder barrel hammer wagon wheel bridge tower castle cabin
    key basket marble crystal lamp mirror pyramid vessel pipe tank
  ].freeze

  class MigrationPot < ActiveRecord::Base
    self.table_name = "pots"
  end

  def up
    add_column :pots, :slug, :string

    used = MigrationPot.where.not(slug: nil).pluck(:slug).to_set
    MigrationPot.where(slug: nil).find_each do |pot|
      candidate = nil
      loop do
        candidate = "#{ADJECTIVES.sample}-#{NOUNS.sample}"
        break unless used.include?(candidate)
      end
      used << candidate
      pot.update_column(:slug, candidate)
    end

    change_column_null :pots, :slug, false
    add_index :pots, :slug, unique: true
  end

  def down
    remove_column :pots, :slug
  end
end
