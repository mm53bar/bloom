# The particular place a pot sits: a shelf, a windowsill, the top of a buffet.
#
# This is where light lives, because light is a property of the place and not of
# the room containing it. A Spot always belongs to an Area and never the other way
# round — the two words are close in ordinary English, so the direction is worth
# stating plainly: Area contains Spots, Spots hold Pots.
class Spot < ApplicationRecord
  # Ordered dimmest to brightest — index comparisons below rely on that order.
  LIGHT_LEVELS = %w[ none low medium bright direct ].freeze

  # What each word is taken to mean in mol/m²/day, so an unmeasured spot can still
  # be compared against a plant's requirement. Estimates standing in for a
  # measurement; a real figure in measured_dli always wins.
  IMPLIED_DLI = {
    "none" => 0.2, "low" => 1.0, "medium" => 3.0, "bright" => 6.0, "direct" => 12.0
  }.freeze

  belongs_to :area
  has_many :pots, -> { order(:position, :name) }, dependent: :destroy
  has_many :plants, through: :pots

  validates :name, presence: true,
            uniqueness: { scope: :area_id, case_sensitive: false }
  validates :natural_light, inclusion: { in: LIGHT_LEVELS }
  validates :position, numericality: { only_integer: true }
  validates :measured_dli, :measured_ppfd, :light_hours,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :in_walk_order, -> {
    joins(:area).order("areas.position", "areas.name", :position, :name)
  }

  def grow_light? = grow_light_entity_id.present?

  # A grow light lifts a spot one step up the scale. It's a coarse model, but it
  # captures the real difference between a dim corner and a dim corner with an LED
  # over it, which is the actionable version of the question.
  def effective_light
    step = LIGHT_LEVELS.index(natural_light) || 0
    step += 1 if grow_light?
    LIGHT_LEVELS[step.clamp(0, LIGHT_LEVELS.length - 1)]
  end

  def measured? = measured_dli.present?

  # The figure every light decision is made from. A measurement where there is one,
  # otherwise whatever the qualitative word implies — so an unmetered spot still
  # gets a sensible answer rather than no answer.
  def effective_dli = measured_dli || IMPLIED_DLI.fetch(effective_light, 0.2)

  # How to refer to this spot in a sentence. An area with one spot is just the
  # area — "the Kitchen", not "the Kitchen, Kitchen".
  def full_name
    area.single_spot? ? area.name : "#{area.name} — #{name}"
  end
end
