class MoistureReading < ApplicationRecord
  belongs_to :pot

  validates :value, numericality: { in: 0..100 }
  validates :read_at, presence: true
  validates :source, presence: true

  before_validation { self.read_at ||= Time.current }

  scope :recent_first, -> { order(read_at: :desc) }
  scope :since, ->(time) { where(read_at: time..) }
end
