class Pot < ApplicationRecord
  # Soil and semi-hydro are two care regimes, not one regime with different
  # numbers. Watering means soak-and-dry in soil and top-up-the-reservoir in
  # semi-hydro; a capacitive probe isn't measuring the same physical quantity in
  # each; and with no soil to hold nutrients, semi-hydro feeds on every refill
  # rather than on a calendar. Every branch on `medium` below is one of those.
  MEDIUMS = %w[ soil semi_hydro ].freeze

  # Northern hemisphere. Feeding a dormant plant in midwinter builds up salts
  # instead of growth, so the fertilizer schedule sleeps outside these months.
  GROWING_SEASON_MONTHS = (3..9).freeze

  belongs_to :location
  has_many :plants, -> { order(:name) }, dependent: :destroy
  has_many :care_events, -> { order(occurred_on: :desc, id: :desc) }, dependent: :destroy
  has_many :moisture_readings, -> { order(read_at: :desc) }, dependent: :destroy

  validates :name, presence: true
  validates :medium, inclusion: { in: MEDIUMS }
  validates :dry_below, :wet_above, numericality: { in: 0..100 }
  validates :check_interval_days, numericality: { greater_than: 0 }
  validates :water_interval_days, :fertilize_interval_days,
            numericality: { greater_than: 0 }, allow_nil: true
  validate :wet_above_exceeds_dry_below

  scope :in_walk_order, -> {
    joins(:location).order("locations.position", "locations.name", :position, :name)
  }
  scope :with_care_data, -> { includes(:location, :plants, :care_events, :moisture_readings) }

  normalizes :voice_aliases, with: ->(list) {
    Array(list).map { |name| name.to_s.strip }.reject(&:blank?).uniq
  }

  def soil? = medium == "soil"
  def semi_hydro? = medium == "semi_hydro"

  def latest_reading = moisture_readings.first

  def last_watered_on = care_events.detect { |e| e.kind == "watered" }&.occurred_on
  def last_fertilized_on = care_events.detect { |e| e.kind == "fertilized" }&.occurred_on

  # A reading is only evidence while it's recent. Past the check interval the pot
  # has had time to dry out again, so we stop trusting it and fall back to cadence.
  def reading_fresh?
    latest_reading.present? && latest_reading.read_at >= check_interval_days.days.ago
  end

  # Recent is not the same as still true. Watering a pot invalidates a reading
  # taken before it — the soil is wet now, whatever the probe said this morning.
  # Care events carry a date rather than a timestamp, so a same-day watering is
  # taken to have followed the reading, which is the usual order: measure, then
  # water what turned out to be dry.
  def reading_superseded?
    return false if latest_reading.blank? || last_watered_on.blank?

    last_watered_on >= latest_reading.read_at.to_date
  end

  # What the pot's state actually rests on: recent, and not already acted upon.
  def reading_actionable? = reading_fresh? && !reading_superseded?

  # Deliberately keyed on staleness alone, not on `reading_actionable?`. A pot you
  # just watered doesn't need re-measuring today — its reading is out of date as
  # evidence, but going and checking it again is not the next useful action.
  def needs_check? = !reading_fresh?

  def needs_water?
    # A probe in expanded clay is reading the air gaps as much as the water, so
    # semi-hydro pots go on refill cadence regardless of what the number says.
    return watering_overdue? if semi_hydro?
    return latest_reading.value < dry_below if reading_actionable?

    watering_overdue?
  end

  def too_wet?
    soil? && reading_actionable? && latest_reading.value > wet_above
  end

  def needs_fertilizer?
    # Semi-hydro nutrients ride along with every reservoir top-up, so there's no
    # separate schedule to fall behind on.
    return false if semi_hydro?
    return false unless growing_season?

    # Unlike water, there's no sensor for this. The record is the only signal we
    # have, so "never fed, and it's growing season" does mean feed it.
    overdue_by_cadence?(fertilize_interval_days, since: last_fertilized_on, when_unknown: true)
  end

  def growing_season? = GROWING_SEASON_MONTHS.cover?(Date.current.month)

  # What to say when standing in front of this pot with a probe in hand.
  def status
    return "too wet" if too_wet?
    return "needs water" if needs_water?
    return "needs checking" if needs_check?

    "fine"
  end

  # The app owns the phrasing, so a voice assistant doesn't have to know that
  # semi-hydro is checked differently from soil.
  def probe_prompt
    if semi_hydro?
      "Check the reservoir on the #{name}."
    else
      "Put the sensor in the #{name}."
    end
  end

  # The sentence to say back after a reading lands. Phrasing deliberately
  # matches what the existing voice automation already speaks, so moving the
  # thresholds in here changes nothing a listener would notice.
  def spoken_verdict
    return "I have no reading for the #{name} yet." if latest_reading.blank?

    percent = latest_reading.value.to_i

    advice =
      if too_wet? then "it's too wet, hold off watering"
      elsif needs_water? then "it needs water"
      else "it's fine for now"
      end

    if semi_hydro?
      "The #{name} reads #{percent} percent, and on its refill schedule #{advice}."
    else
      "The #{name} is at #{percent} percent, #{advice}."
    end
  end

  def voice_alias_list = voice_aliases.join(", ")

  def voice_alias_list=(value)
    self.voice_aliases = value.to_s.split(",")
  end

  # Every name this pot answers to, for a voice assistant matching by ear.
  def spoken_names = ([ name ] + voice_aliases).map { |n| n.downcase.strip }

  def self.matching_spoken(spoken)
    needle = spoken.to_s.downcase.strip
    with_care_data.find { |pot| pot.spoken_names.include?(needle) }
  end

  private

  # Watering has a sensor behind it, so an empty history means "we don't know" —
  # and the honest response to not knowing is to go and measure, which
  # needs_check? already reports. Claiming a never-recorded pot is dry would
  # make every pot in a fresh install shout for water on day one.
  def watering_overdue?
    overdue_by_cadence?(water_interval_days, since: last_watered_on, when_unknown: false)
  end

  def overdue_by_cadence?(interval, since:, when_unknown:)
    return false if interval.blank?
    return when_unknown if since.blank?

    since <= interval.days.ago.to_date
  end

  def wet_above_exceeds_dry_below
    return if dry_below.blank? || wet_above.blank?
    return if wet_above > dry_below

    errors.add(:wet_above, "must be greater than dry_below")
  end
end
