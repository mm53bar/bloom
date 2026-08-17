require "test_helper"

class PlantTest < ActiveSupport::TestCase
  test "a plant in bright enough light is satisfied" do
    assert plants(:jade).light_satisfied?
    assert_equal 0.0, plants(:jade).light_deficit
  end

  test "a bright-light plant in an unlit cellar is not" do
    starved = plants(:starved)

    assert_not starved.light_satisfied?
    assert_equal :poor, starved.light_severity
    # Wants 6.0, a spot implying 0.2.
    assert_equal 5.8, starved.light_deficit
  end

  test "a measured spot overrides the estimate its word implies" do
    # Two shelves that the qualitative ladder cannot tell apart: same natural light,
    # both with a grow light, so both compute as "low". Measurement says otherwise.
    weak = spots(:landing_shelf)
    weak.update!(measured_dli: 1.5, measured_ppfd: 60, light_hours: 7)
    strong = spots(:landing_corner)
    strong.update!(grow_light_entity_id: "switch.example", measured_dli: 11.3,
                   measured_ppfd: 450, light_hours: 7)

    assert_equal weak.effective_light, strong.effective_light
    assert_equal 1.5, weak.effective_dli
    assert_equal 11.3, strong.effective_dli

    fussy = Plant.new(light_requirement: "bright")
    assert_equal 6.0, fussy.dli_required
    assert weak.effective_dli < fussy.dli_required
    assert strong.effective_dli > fussy.dli_required
  end

  test "an explicit minimum overrides the requirement default" do
    plant = plants(:jade)
    assert_equal 6.0, plant.dli_required

    plant.update!(dli_minimum: 2.0)
    assert_equal 2.0, plant.dli_required
  end

  test "a plant may tolerate deep shade" do
    # Snake plants and pothos live in near-dark indefinitely. Barring "none" as a
    # requirement flagged them for being somewhere they are perfectly content.
    tough = plants(:jade)
    tough.update!(light_requirement: "none")

    assert_equal 0.3, tough.dli_required
    assert tough.light_satisfied?
  end

  test "half of what is needed is a compromise, less than half is the wrong place" do
    plant = plants(:jade)          # wants 6.0, in a bright spot
    plant.spot.update!(measured_dli: 3.5)
    assert_equal :marginal, plant.reload.light_severity

    plant.spot.update!(measured_dli: 2.0)
    assert_equal :poor, plant.reload.light_severity
  end

  test "a grow light can rescue an otherwise dim spot" do
    pothos = plants(:golden_pothos)

    # Wants low light; the landing is low but has an LED over it.
    assert_equal "low", pothos.light_requirement
    assert pothos.light_satisfied?
  end

  test "a requirement outside the scale is still rejected" do
    plant = plants(:jade)
    plant.light_requirement = "blinding"

    assert_not plant.valid?
  end

  test "plants reach their spot and area through their pot" do
    assert_equal spots(:sunroom_sill), plants(:jade).spot
    assert_equal areas(:sunroom), plants(:jade).area
  end

  test "two plants in one area can disagree about whether their light is enough" do
    # Same area, different spots — which is only expressible because light is on Spot.
    shelf_plant = plants(:golden_pothos)                       # low light, on the lit shelf
    corner_plant = Plant.create!(pot: pots_in_corner, name: "Fussy",
                                 light_requirement: "bright")

    assert shelf_plant.light_satisfied?
    assert_not corner_plant.light_satisfied?
    assert_equal shelf_plant.area, corner_plant.area
  end

  private

  def pots_in_corner
    Pot.create!(spot: spots(:landing_corner), name: "Corner Pot",
                dry_below: 20, wet_above: 80, check_interval_days: 7)
  end

  test "a reference url must be http or https" do
    plant = plants(:jade)
    plant.reference_url = "javascript:alert(1)"

    assert_not plant.valid?
    assert_includes plant.errors[:reference_url], "must start with http:// or https://"
  end

  test "safe_reference_url refuses anything that is not a web address" do
    plant = plants(:jade)
    plant.update_column(:reference_url, "javascript:alert(1)")

    assert_nil plant.reload.safe_reference_url
  end

  test "safe_reference_url passes a normal link through" do
    assert_equal "https://example.com/notes/pothos", plants(:golden_pothos).safe_reference_url
  end
end
