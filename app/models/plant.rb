class Plant < ApplicationRecord
  # A plant can want anything a location can offer, except "none".
  LIGHT_REQUIREMENTS = (Location::LIGHT_LEVELS - %w[ none ]).freeze

  belongs_to :pot
  has_one :location, through: :pot

  validates :name, presence: true
  validates :light_requirement, inclusion: { in: LIGHT_REQUIREMENTS }

  # This arrives over an unauthenticated API and is rendered as a link, so a
  # "javascript:" or "data:" URL would be a stored XSS waiting for a click.
  # Restricting the scheme here means the view can trust it.
  # Anchored at both ends on purpose: with only \A, a value like
  # "https://ok\njavascript:alert(1)" satisfies the match and still carries a
  # payload, because \A anchors the string but nothing pins the end.
  validates :reference_url, allow_blank: true, format: {
    with: %r{\Ahttps?://\S+\z}i,
    message: "must start with http:// or https://"
  }

  scope :by_name, -> { order(:name) }

  # Does this plant's spot provide at least the light it asks for? Comparing
  # against effective_light means a grow light can rescue an otherwise dim
  # corner — which is the actionable version of the question.
  def light_satisfied?
    Location::LIGHT_LEVELS.index(location.effective_light) >=
      Location::LIGHT_LEVELS.index(light_requirement)
  end

  # Belt and braces: the validation above covers anything saved through the app,
  # and this re-checks at render time so a row written by some future path — a
  # console session, a restored backup — still can't inject a scheme.
  def safe_reference_url
    return if reference_url.blank?

    uri = URI.parse(reference_url)
    reference_url if uri.is_a?(URI::HTTP)
  rescue URI::InvalidURIError
    nil
  end

  def light_shortfall
    return 0 if light_satisfied?

    Location::LIGHT_LEVELS.index(light_requirement) -
      Location::LIGHT_LEVELS.index(location.effective_light)
  end
end
