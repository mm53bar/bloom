require "test_helper"

class SpotTest < ActiveSupport::TestCase
  test "two spots in one area can provide completely different light" do
    # The reason this model has two levels at all.
    shelf = spots(:landing_shelf)
    corner = spots(:landing_corner)

    assert_equal shelf.area, corner.area
    assert_equal "low", shelf.natural_light
    assert_equal "low", corner.natural_light
    assert_equal "medium", shelf.effective_light   # has an LED over it
    assert_equal "low", corner.effective_light     # does not
  end

  test "a grow light lifts a spot one step up the scale" do
    assert spots(:landing_shelf).grow_light?
    assert_equal "medium", spots(:landing_shelf).effective_light
  end

  test "a spot without a grow light provides exactly its natural light" do
    assert_not spots(:sunroom_sill).grow_light?
    assert_equal "bright", spots(:sunroom_sill).effective_light
  end

  test "effective light cannot climb past the top of the scale" do
    spot = spots(:sunroom_sill)
    spot.update!(natural_light: "direct", grow_light_entity_id: "switch.example")

    assert_equal "direct", spot.effective_light
  end

  test "a spot name only has to be unique within its area" do
    # "Shelf" is taken on the Landing but free in the Cellar.
    assert_not areas(:landing).spots.build(name: "Shelf").valid?
    assert areas(:cellar).spots.build(name: "Shelf").valid?
  end

  test "a single-spot area reads as just the area name" do
    assert_equal "Sunroom", spots(:sunroom_sill).full_name
  end

  test "a subdivided area names both levels" do
    assert_equal "Landing — Shelf", spots(:landing_shelf).full_name
    assert_equal "Landing — Far Corner", spots(:landing_corner).full_name
  end

  test "walk order runs area by area, then spot by spot" do
    assert_equal [ "Sunroom", "Landing — Shelf", "Landing — Far Corner", "Cellar" ],
                 Spot.in_walk_order.map(&:full_name)
  end
end
