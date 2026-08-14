class Location < ApplicationRecord
  # Ordered dimmest to brightest — index comparisons below rely on that order.
  LIGHT_LEVELS = %w[ none low medium bright direct ].freeze

  has_many :pots, -> { order(:position, :name) }, dependent: :destroy
  has_many :plants, through: :pots

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :natural_light, inclusion: { in: LIGHT_LEVELS }
  validates :position, numericality: { only_integer: true }

  scope :in_walk_order, -> { order(:position, :name) }

  def grow_light? = grow_light_entity_id.present?

  # A grow light lifts a spot one step up the scale. It's a coarse model, but it
  # captures the real difference between a dim corner and a dim corner with an
  # LED over it — which is the whole reason to track lights at all.
  def effective_light
    step = LIGHT_LEVELS.index(natural_light) || 0
    step += 1 if grow_light?
    LIGHT_LEVELS[step.clamp(0, LIGHT_LEVELS.length - 1)]
  end
end
