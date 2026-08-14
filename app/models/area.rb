# The part of a home a person names: the living room, the kitchen, the deck.
#
# An Area owns no light. Light varies *within* a room — a shelf in a south window
# and a shelf on the opposite wall provide nothing like the same thing — so it
# lives on Spot, which is the level a pot actually sits at. Keeping light off Area
# means there is exactly one place to read it from.
#
# "Area" rather than "Room" for two reasons: a deck or a balcony is not a room,
# and Home Assistant calls this same level an area, which makes `ha_area` a
# pairing rather than a translation.
class Area < ApplicationRecord
  has_many :spots, -> { order(:position, :name) }, dependent: :destroy
  has_many :pots, through: :spots
  has_many :plants, through: :pots

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :position, numericality: { only_integer: true }

  # Most areas contain exactly one spot, and making someone name it would be
  # busywork. One is created automatically; a second is what you add when the
  # light genuinely differs.
  after_create :create_default_spot

  scope :in_walk_order, -> { order(:position, :name) }

  # True when this area has never been subdivided, in which case the UI can talk
  # about the area alone and never mention spots.
  def single_spot? = spots.size == 1

  def default_spot = spots.first

  private

  def create_default_spot
    spots.create!(name: name)
  end
end
