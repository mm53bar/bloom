require "test_helper"

class PlantTest < ActiveSupport::TestCase
  test "a plant in bright enough light is satisfied" do
    assert plants(:jade).light_satisfied?
    assert_equal 0, plants(:jade).light_shortfall
  end

  test "a bright-light plant in an unlit cellar is not" do
    starved = plants(:starved)

    assert_not starved.light_satisfied?
    assert_equal 3, starved.light_shortfall
  end

  test "a grow light can rescue an otherwise dim spot" do
    pothos = plants(:golden_pothos)

    # Wants low light; the landing is low but has an LED over it.
    assert_equal "low", pothos.light_requirement
    assert pothos.light_satisfied?
  end

  test "a plant cannot ask for no light at all" do
    plant = plants(:jade)
    plant.light_requirement = "none"

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
