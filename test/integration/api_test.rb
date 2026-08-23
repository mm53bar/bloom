require "test_helper"

# The JSON contract, which is what Home Assistant and the data loader talk to.
# Breaking anything asserted here means editing automations on the other side,
# so these are deliberately specific about shape.
class ApiTest < ActionDispatch::IntegrationTest
  test "the walk returns every pot in room order with what's needed to run it" do
    get walk_pots_path(format: :json)

    assert_response :success
    body = response.parsed_body

    assert_equal 4, body["pot_count"]
    assert_equal [ "Big Fern", "Succulent Bowl", "Clay Ball Pothos", "Forgotten Pot" ],
                 body["pots"].map { |p| p["name"] }

    fern = body["pots"].first
    assert_equal "Sunroom", fern["area"]
    assert_equal "Sunroom", fern["spot"]   # single-spot area reads as just the area
    assert_equal "Put the sensor in the Sunroom Big Fern.", fern["prompt"]
    assert_equal [ "the big fern", "sunroom fern" ], fern["aliases"]
    assert_equal 30, fern["dry_below"]
    assert_includes fern["plants"], "Boston Fern"
    assert_match %r{/pots/[a-z]+-[a-z]+/moisture_readings\.json\z}, fern["record_reading_url"]
  end

  test "the walk speaks about the reservoir for a semi-hydro pot" do
    get walk_pots_path(format: :json)

    pothos = response.parsed_body["pots"].find { |p| p["name"] == "Clay Ball Pothos" }

    # Landing has two spots, so the spot names it rather than the area.
    assert_equal "Check the reservoir on the Shelf Clay Ball Pothos.", pothos["prompt"]
  end

  test "posting a reading records it and returns the verdict already phrased" do
    pot = pots(:fern)

    assert_difference -> { pot.moisture_readings.count }, 1 do
      post pot_moisture_readings_path(pot, format: :json),
           params: { moisture_reading: { value: 12, source: "zigbee" } }, as: :json
    end

    assert_response :created
    body = response.parsed_body

    assert_equal 12.0, body["value"]
    assert_equal "zigbee", body["source"]
    assert_equal "The Sunroom Big Fern is at 12 percent, it needs water.", body["verdict"]
    assert_equal "needs water", body.dig("pot", "status")
    assert body.dig("pot", "needs_water")
  end

  test "a reading on a semi-hydro pot is recorded but does not decide watering" do
    pot = pots(:pothos)
    pot.care_events.create!(kind: "watered", occurred_on: 1.day.ago)

    post pot_moisture_readings_path(pot, format: :json),
         params: { moisture_reading: { value: 3, source: "zigbee" } }, as: :json

    assert_response :created
    assert_not response.parsed_body.dig("pot", "needs_water")
  end

  test "an out-of-range reading is rejected rather than stored" do
    pot = pots(:fern)

    assert_no_difference -> { pot.moisture_readings.count } do
      post pot_moisture_readings_path(pot, format: :json),
           params: { moisture_reading: { value: 250 } }, as: :json
    end

    assert_response :unprocessable_entity
  end

  test "marking a pot watered records a care event" do
    pot = pots(:fern)

    assert_difference -> { pot.care_events.watered.count }, 1 do
      post watered_pot_path(pot, format: :json), as: :json
    end

    assert_response :success
    assert_equal Date.current.to_s, response.parsed_body["last_watered_on"]
  end

  test "due buckets pots by what they actually need" do
    pots(:fern).moisture_readings.create!(value: 5, read_at: 1.hour.ago, source: "test")
    pots(:succulent_bowl).moisture_readings.create!(value: 50, read_at: 1.hour.ago, source: "test")

    get due_pots_path(format: :json)

    assert_response :success
    body = response.parsed_body

    assert_includes body["needs_water"].map { |p| p["name"] }, "Big Fern"
    assert_not_includes body["needs_water"].map { |p| p["name"] }, "Succulent Bowl"
    assert_equal "Sunroom", body["needs_water"].first["area"]
    assert_includes body["needs_check"].map { |p| p["name"] }, "Forgotten Pot"
    assert_equal body["needs_water"].size, body.dig("counts", "needs_water")
  end

  test "a pot can be created over the API, which is how real data gets loaded" do
    assert_difference -> { Pot.count }, 1 do
      post pots_path(format: :json), params: {
        pot: {
          spot_id: spots(:sunroom_sill).id,
          name: "New Pot",
          medium: "semi_hydro",
          voice_aliases: [ "the new one" ],
          dry_below: 15,
          wet_above: 90,
          check_interval_days: 10
        }
      }, as: :json
    end

    assert_response :created
    body = response.parsed_body

    assert_equal "New Pot", body["name"]
    assert_equal "semi_hydro", body["medium"]
    assert_equal [ "the new one" ], body["aliases"]
  end

  test "an invalid pot comes back with errors rather than a 500" do
    post pots_path(format: :json), params: {
      pot: { spot_id: spots(:sunroom_sill).id, name: "Bad", dry_below: 80, wet_above: 20 }
    }, as: :json

    assert_response :unprocessable_entity
    assert_includes response.parsed_body.dig("errors", "wet_above"), "must be greater than dry_below"
  end

  test "pots can be updated in place, so the loader can be re-run" do
    pot = pots(:fern)

    patch pot_path(pot, format: :json),
          params: { pot: { check_interval_days: 21 } }, as: :json

    assert_response :success
    assert_equal 21, pot.reload.check_interval_days
  end

  test "areas and plants are creatable over the API too" do
    # Creating an area also creates its one spot, so a caller adding a simple
    # room never has to know spots exist.
    assert_difference [ -> { Area.count }, -> { Spot.count } ], 1 do
      post areas_path(format: :json),
           params: { area: { name: "Porch", position: 9 } }, as: :json
    end
    assert_response :created
    assert response.parsed_body["single_spot"]

    assert_difference -> { Plant.count }, 1 do
      post plants_path(format: :json), params: {
        plant: { pot_id: pots(:fern).id, name: "New Plant", light_requirement: "low" }
      }, as: :json
    end
    assert_response :created
  end

  test "reading history comes back newest first" do
    pot = pots(:fern)
    pot.moisture_readings.create!(value: 10, read_at: 3.days.ago, source: "test")
    pot.moisture_readings.create!(value: 40, read_at: 1.day.ago, source: "test")

    get pot_moisture_readings_path(pot, format: :json)

    assert_response :success
    assert_equal [ 40.0, 10.0 ], response.parsed_body.map { |r| r["value"] }
  end

  test "a spot can be added to an area over the API" do
    area = areas(:sunroom)

    assert_difference -> { area.spots.count }, 1 do
      post area_spots_path(area, format: :json), params: {
        spot: { name: "Dark Corner", natural_light: "low" }
      }, as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal "low", body["effective_light"]
    assert_equal "Sunroom — Dark Corner", body["full_name"]
  end

  test "a pot reports both the area and the spot it sits in" do
    get pot_path(pots(:pothos), format: :json)

    assert_response :success
    body = response.parsed_body

    assert_equal "Landing", body.dig("area", "name")
    assert_equal "Shelf", body.dig("spot", "name")
    # The grow light on that shelf, not anything about the area.
    assert_equal "medium", body.dig("spot", "effective_light")
  end

  test "a pot carries its light verdict for each plant in it" do
    get pot_path(pots(:orphan), format: :json)

    assert_response :success
    plant = response.parsed_body["plants"].first

    assert_equal "Sad Succulent", plant["name"]
    assert_not plant["light_satisfied"]
  end

  # Forgery protection is disabled in the test environment, so every other test in
  # this file would pass even if the API rejected all machine callers — which is
  # exactly what happened: a JSON POST died with InvalidAuthenticityToken against a
  # real server while the suite stayed green. This turns protection on for the
  # duration and asserts both halves, so the contrast proves it is genuinely active.
  test "the JSON API takes posts with no CSRF token while HTML forms still demand one" do
    with_forgery_protection do
      post pot_moisture_readings_path(pots(:fern), format: :json),
           params: { moisture_reading: { value: 20, source: "zigbee" } }, as: :json
      assert_response :created

      # Same endpoint, HTML format, no token: rejected. Were protection not really
      # on, this would come back as a redirect and the test above would be hollow.
      post pot_moisture_readings_path(pots(:fern)), params: { moisture_reading: { value: 20 } }
      assert_response :unprocessable_entity
    end
  end

  test "a spot can be moved to another area, taking its pots with it" do
    spot = spots(:landing_corner)
    pot = Pot.create!(spot: spot, name: "Travelling Pot",
                      dry_below: 20, wet_above: 80, check_interval_days: 7)

    patch spot_path(spot, format: :json),
          params: { spot: { area_id: areas(:cellar).id } }, as: :json

    assert_response :success
    assert_equal "Cellar", response.parsed_body.dig("area", "name")
    assert_equal areas(:cellar), pot.reload.area
  end

  private


  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
