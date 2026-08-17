class Plant < ApplicationRecord
  # Every level a spot can offer, "none" included. Excluding it was a mistake:
  # snake plants, ZZ plants and pothos tolerate deep shade indefinitely, and
  # without this they get flagged for living somewhere they are perfectly content.
  LIGHT_REQUIREMENTS = Spot::LIGHT_LEVELS

  # The DLI each requirement implies, in mol/m²/day — the *minimum* the plant needs
  # rather than what it would ideally enjoy. dli_minimum overrides it per plant.
  REQUIREMENT_DLI = {
    "none" => 0.3, "low" => 1.5, "medium" => 3.0, "bright" => 6.0, "direct" => 10.0
  }.freeze

  belongs_to :pot
  has_one :spot, through: :pot
  has_one :area, through: :spot

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

  # The minimum daily light this plant needs: an explicit figure if given,
  # otherwise the default implied by its qualitative requirement.
  def dli_required = dli_minimum || REQUIREMENT_DLI.fetch(light_requirement, 1.5)

  # Both sides are in mol/m²/day now, so a measured spot and an unmeasured one are
  # answered the same way and no counting of rungs is involved.
  def light_satisfied? = spot.effective_dli >= dli_required

  # How far short, as a fraction of what is needed.
  def light_ratio = (spot.effective_dli / dli_required).to_f

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

  # Below half of what it needs is a plant in the wrong place; between half and all
  # of it is a compromise worth noting.
  def light_severity
    return nil if light_satisfied?

    light_ratio >= 0.5 ? :marginal : :poor
  end

  # The shortfall in mol/m²/day — the number that says whether a different spot or
  # a better lamp would actually close the gap.
  def light_deficit
    return 0.0 if light_satisfied?

    (dli_required - spot.effective_dli).round(2)
  end
end
