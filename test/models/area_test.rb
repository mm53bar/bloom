require "test_helper"

class AreaTest < ActiveSupport::TestCase
  test "a new area gets one spot named after it, so single-spot areas need no thought" do
    area = Area.create!(name: "Porch")

    assert_equal 1, area.spots.size
    assert_equal "Porch", area.default_spot.name
    assert area.single_spot?
  end

  test "an area with a second spot is no longer single" do
    assert_not areas(:landing).single_spot?
    assert_equal 2, areas(:landing).spots.size
  end

  test "areas reach pots and plants through their spots" do
    assert_includes areas(:sunroom).pots, pots(:fern)
    assert_includes areas(:sunroom).plants, plants(:boston_fern)
  end

  test "names are unique regardless of case" do
    assert_not Area.new(name: "sunroom").valid?
  end

  test "walk order follows position" do
    assert_equal [ "Sunroom", "Landing", "Cellar" ], Area.in_walk_order.map(&:name)
  end

  test "destroying an area takes its spots and their pots with it" do
    assert_difference -> { Spot.count }, -2 do
      assert_difference -> { Pot.count }, -1 do
        areas(:landing).destroy!
      end
    end
  end

  test "an area holds no light of its own" do
    # Light lives on Spot deliberately — there must be exactly one place to read it.
    assert_not Area.new.respond_to?(:natural_light)
    assert_not Area.new.respond_to?(:effective_light)
  end
end
