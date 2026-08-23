require "test_helper"

# Rack integration tests rather than browser system tests — see
# docs/adr/20260814-integration-tests-over-system-tests.md.
class BrowsingTest < ActionDispatch::IntegrationTest
  test "the pot list groups pots under their location" do
    get root_path

    assert_response :success
    assert_select "h2", text: /Sunroom/
    assert_select "a", text: "Big Fern"
    assert_select "a", text: "Clay Ball Pothos"
  end

  test "an empty install explains what to do first" do
    Pot.destroy_all

    get root_path

    assert_response :success
    assert_select "p", text: /Nothing here yet/
  end

  test "the due page says so when nothing is outstanding" do
    Pot.find_each do |pot|
      pot.moisture_readings.create!(value: 60, read_at: 1.hour.ago, source: "test")
      pot.care_events.create!(kind: "watered", occurred_on: Date.current)
      pot.care_events.create!(kind: "fertilized", occurred_on: Date.current)
    end

    get due_pots_path

    assert_response :success
    assert_select "p", text: /Nothing needs anything/
  end

  test "a pot page shows its plants, readings and history" do
    pot = pots(:succulent_bowl)
    pot.moisture_readings.create!(value: 33, read_at: 1.day.ago, source: "manual")
    pot.care_events.create!(kind: "repotted", occurred_on: 2.months.ago)

    get pot_path(pot)

    assert_response :success
    assert_select "h1", text: "Succulent Bowl"
    assert_select "a", text: "Jade"
    assert_select "a", text: "Echeveria"
    assert_select "li", text: /33%/
    assert_select "li", text: /Repotted/
  end

  test "a semi-hydro pot explains why its thresholds are not in charge" do
    get pot_path(pots(:pothos))

    assert_response :success
    assert_select "p", text: /watering follows the refill schedule/
  end

  test "the plant list surfaces plants short of light" do
    get plants_path

    assert_response :success
    assert_select "h2", text: /Wanting more light/
    assert_select "a", text: "Sad Succulent"
  end

  test "recording a reading reports the verdict back" do
    pot = pots(:fern)

    post pot_moisture_readings_path(pot), params: { moisture_reading: { value: 8 } }

    assert_redirected_to pot
    follow_redirect!
    assert_select "p", text: /is at 8 percent, it needs water/
  end

  test "marking watered from the list returns to the list" do
    post watered_pot_path(pots(:fern)), headers: { "HTTP_REFERER" => pots_url }

    assert_redirected_to pots_url
    assert_equal Date.current, pots(:fern).care_events.watered.first.occurred_on
  end

  test "pots can be created and edited through the forms" do
    assert_difference -> { Pot.count }, 1 do
      post pots_path, params: {
        pot: {
          spot_id: spots(:cellar_bench).id, name: "Form Pot", medium: "soil",
          dry_below: 20, wet_above: 80, check_interval_days: 7,
          voice_alias_list: "formy, the form pot"
        }
      }
    end

    pot = Pot.find_by(name: "Form Pot")
    assert_equal [ "formy", "the form pot" ], pot.voice_aliases
    assert_redirected_to pot
  end

  test "areas, spots and plants have working pages" do
    get areas_path
    assert_response :success
    assert_select "a", text: "Sunroom"

    get area_path(areas(:landing))
    assert_response :success
    assert_select "a", text: "Shelf"
    assert_select "a", text: "Far Corner"
    assert_select "span", text: /grow light/

    get spot_path(spots(:landing_corner))
    assert_response :success
    assert_select "h1", text: "Far Corner"

    get plant_path(plants(:jade))
    assert_response :success
    assert_select "h1", text: "Jade"
  end

  test "an area page shows each spot's own light rather than the area's" do
    get area_path(areas(:landing))

    assert_response :success
    # Both spots are "low" naturally; only the shelf has a lamp lifting it.
    assert_select "span", text: /grow light/, count: 1
  end

  test "removing a pot takes its plants and readings with it" do
    pot = pots(:succulent_bowl)

    assert_difference -> { Plant.count }, -2 do
      delete pot_path(pot)
    end

    assert_redirected_to pots_path
  end

  # --- build footer -----------------------------------------------------------

  test "the footer links the build SHA to its commit" do
    with_revision("abc123def4567890", "abc123d") do
      get root_path

      assert_select "footer a[href=?]",
                    "https://github.com/mm53bar/bloom/commit/abc123def4567890",
                    text: "abc123d"
    end
  end

  test "the footer shows a plain marker when not running a built image" do
    with_revision("dev", "dev") do
      get root_path

      assert_select "footer span", text: "dev"
      assert_select "footer a", false, "should not link to a commit that doesn't exist"
    end
  end

  test "an unknown revision does not become a broken commit link" do
    # The Dockerfile writes "unknown" when it builds without a .git directory.
    with_revision("unknown", "unknown") do
      get root_path

      assert_select "footer a", false
    end
  end

  test "a badly mismatched pot is flagged on the list and explained on its page" do
    get pots_path
    assert_response :success
    assert_select "span", text: "needs attention"

    get pot_path(pots(:orphan))
    assert_response :success
    assert_select "p", text: /wrong place for what's in it/
    assert_select "li", text: /Sad Succulent.*wants bright light/m
  end

  test "the mismatch badge is separate from the watering status" do
    read = pots(:orphan).moisture_readings.create!(value: 60, read_at: 1.hour.ago, source: "test")

    get pots_path

    assert_response :success
    # Watering is fine; the condition is not. Both must be visible at once.
    assert_select "span", text: "fine"
    assert_select "span", text: "needs attention"
  end

  private
  def with_revision(sha, short)
    original = [ Rails.configuration.x.git_sha, Rails.configuration.x.git_sha_short ]
    Rails.configuration.x.git_sha = sha
    Rails.configuration.x.git_sha_short = short
    yield
  ensure
    Rails.configuration.x.git_sha, Rails.configuration.x.git_sha_short = original
  end
end
