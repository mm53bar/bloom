require "test_helper"

class LocationTest < ActiveSupport::TestCase
  test "a grow light lifts a location one step up the scale" do
    landing = locations(:landing)

    assert_equal "low", landing.natural_light
    assert landing.grow_light?
    assert_equal "medium", landing.effective_light
  end

  test "a location without a grow light provides exactly its natural light" do
    sunroom = locations(:sunroom)

    assert_not sunroom.grow_light?
    assert_equal "bright", sunroom.effective_light
  end

  test "effective light cannot climb past the top of the scale" do
    sunroom = locations(:sunroom)
    sunroom.update!(natural_light: "direct", grow_light_entity_id: "switch.example")

    assert_equal "direct", sunroom.effective_light
  end

  test "names are unique regardless of case" do
    duplicate = Location.new(name: "sunroom", natural_light: "low")

    assert_not duplicate.valid?
  end

  test "walk order follows position" do
    assert_equal [ "Sunroom", "Landing", "Cellar" ], Location.in_walk_order.map(&:name)
  end
end
