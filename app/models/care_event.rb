class CareEvent < ApplicationRecord
  # One table rather than five near-identical ones. They share a shape — a pot,
  # a date, an optional note — and keeping them together gives each pot a single
  # readable timeline. Adding a sixth kind is an enum value, not a migration.
  KINDS = %w[ watered fertilized repotted treated pruned ].freeze

  belongs_to :pot

  validates :kind, inclusion: { in: KINDS }
  validates :occurred_on, presence: true

  before_validation { self.occurred_on ||= Date.current }

  KINDS.each do |kind|
    scope kind, -> { where(kind: kind) }
  end

  scope :recent_first, -> { order(occurred_on: :desc, id: :desc) }

  def to_s = "#{kind} on #{occurred_on}"
end
