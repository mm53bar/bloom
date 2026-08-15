require "test_helper"

class PotTest < ActiveSupport::TestCase
  setup do
    @fern = pots(:fern)               # soil, dry_below 30, check every 7 days
    @pothos = pots(:pothos)           # semi-hydro, refill every 14 days
  end

  # --- readings as evidence -------------------------------------------------

  test "a fresh reading below dry_below means the pot wants water" do
    read(@fern, 18, at: 2.days.ago)

    assert @fern.reload.needs_water?
    assert_equal "needs water", @fern.status
  end

  test "a fresh reading above dry_below means it does not" do
    read(@fern, 55, at: 2.days.ago)

    assert_not @fern.reload.needs_water?
    assert_equal "fine", @fern.status
  end

  test "a reading older than the check interval stops counting as evidence" do
    read(@fern, 55, at: 10.days.ago)

    assert_not @fern.reload.reading_fresh?
  end

  test "a stale reading falls back to watering cadence" do
    read(@fern, 55, at: 10.days.ago)
    water(@fern, on: 30.days.ago)

    # The number says wet, but it's ten days old and the pot hasn't been watered
    # in a month — cadence wins.
    assert @fern.reload.needs_water?
  end

  test "a pot past wet_above is flagged rather than watered again" do
    read(@fern, 95, at: 1.day.ago)

    assert @fern.reload.too_wet?
    assert_equal "too wet", @fern.status
  end

  test "watering supersedes an earlier dry reading" do
    read(@fern, 9, at: 2.hours.ago)
    assert @fern.reload.needs_water?

    # You measured it, found it dry, and watered it. The reading is still recent
    # but no longer describes the pot.
    water(@fern, on: Date.current)

    assert_not @fern.reload.needs_water?
    assert @fern.reload.reading_superseded?
  end

  test "watering does not make a pot immediately need checking again" do
    read(@fern, 9, at: 2.hours.ago)
    water(@fern, on: Date.current)

    # The reading is stale as evidence, but re-measuring a pot you just watered
    # is not a useful next action.
    assert_not @fern.reload.needs_check?
  end

  test "a reading taken after watering counts again" do
    water(@fern, on: 1.day.ago)
    read(@fern, 9, at: 1.hour.ago)

    assert_not @fern.reload.reading_superseded?
    assert @fern.reload.needs_water?
  end

  test "watering clears a too-wet flag as well" do
    read(@fern, 95, at: 2.hours.ago)
    assert @fern.reload.too_wet?

    water(@fern, on: Date.current)

    assert_not @fern.reload.too_wet?
  end

  # --- semi-hydro is a different regime ------------------------------------

  test "semi-hydro ignores a dry probe reading and goes on refill cadence" do
    read(@pothos, 5, at: 1.day.ago)
    water(@pothos, on: 2.days.ago)

    # 5% in expanded clay is not the same fact as 5% in soil, so the reservoir
    # cadence decides — and it was topped up two days ago.
    assert_not @pothos.reload.needs_water?
  end

  test "semi-hydro wants water once the refill cadence has elapsed" do
    read(@pothos, 90, at: 1.day.ago)
    water(@pothos, on: 20.days.ago)

    assert @pothos.reload.needs_water?
  end

  test "semi-hydro is never too wet by probe reading" do
    read(@pothos, 100, at: 1.day.ago)

    assert_not @pothos.reload.too_wet?
  end

  test "semi-hydro never falls behind on fertilizer because feeding rides along" do
    travel_to Date.new(2026, 6, 15) do
      assert_not @pothos.reload.needs_fertilizer?
    end
  end

  # --- checking is not the same question as watering ------------------------

  test "a pot with no readings needs checking" do
    assert @fern.needs_check?
    assert_equal "needs checking", @fern.status
  end

  test "a pot with no history at all asks to be measured, not watered" do
    # No readings and no watering record is an absence of evidence, not evidence
    # of dryness — otherwise every pot in a fresh install shouts on day one.
    assert_nil @fern.last_watered_on
    assert_not @fern.needs_water?
    assert @fern.needs_check?
  end

  test "a recently read pot does not need checking" do
    read(@fern, 50, at: 1.day.ago)

    assert_not @fern.reload.needs_check?
  end

  # --- fertilizer sleeps in winter -----------------------------------------

  test "fertilizer is due in season when the pot has never been fed" do
    travel_to Date.new(2026, 6, 15) do
      assert @fern.needs_fertilizer?
    end
  end

  test "fertilizer is not due outside the growing season" do
    travel_to Date.new(2026, 1, 15) do
      assert_not @fern.needs_fertilizer?
      assert_not @fern.growing_season?
    end
  end

  test "fertilizer is not due again within the interval" do
    travel_to Date.new(2026, 6, 15) do
      @fern.care_events.create!(kind: "fertilized", occurred_on: 5.days.ago)

      assert_not @fern.reload.needs_fertilizer?
    end
  end

  test "a pot with no fertilizer interval is never due" do
    travel_to Date.new(2026, 6, 15) do
      assert_nil pots(:succulent_bowl).fertilize_interval_days
      assert_not pots(:succulent_bowl).needs_fertilizer?
    end
  end

  # --- voice names ----------------------------------------------------------

  test "spoken names cover the pot name and its aliases" do
    assert_includes @fern.spoken_names, "big fern"
    assert_includes @fern.spoken_names, "sunroom fern"
  end

  test "matching_spoken finds a pot by alias regardless of case" do
    assert_equal @fern, Pot.matching_spoken("The Big Fern")
  end

  test "matching_spoken returns nil rather than guessing" do
    assert_nil Pot.matching_spoken("something nobody owns")
  end

  test "the alias list round-trips through a comma-separated string" do
    @fern.voice_alias_list = "one, two ,, three"

    assert_equal %w[ one two three ], @fern.voice_aliases
    assert_equal "one, two, three", @fern.voice_alias_list
  end

  # --- validation -----------------------------------------------------------

  test "wet_above must sit above dry_below" do
    @fern.wet_above = @fern.dry_below - 1

    assert_not @fern.valid?
    assert_includes @fern.errors[:wet_above], "must be greater than dry_below"
  end

  test "medium is restricted to the regimes the app models" do
    @fern.medium = "hydroponic"

    assert_not @fern.valid?
  end

  # --- naming ------------------------------------------------------------------

  test "a name unique across the house needs no qualifier" do
    assert_equal "Big Fern", @fern.display_name
  end

  test "a name shared by two pots is qualified by area" do
    # Two "Twin" pots in different areas — the exact situation trimming the old
    # "TV Room Snake Plant" style names creates.
    twin_a = Pot.create!(spot: spots(:sunroom_sill), name: "Twin",
                         dry_below: 20, wet_above: 80, check_interval_days: 7)
    twin_b = Pot.create!(spot: spots(:cellar_bench), name: "Twin",
                         dry_below: 20, wet_above: 80, check_interval_days: 7)

    duplicates = Pot.duplicated_names
    assert_equal "Twin (Sunroom)", twin_a.display_name(duplicates)
    assert_equal "Twin (Cellar)", twin_b.display_name(duplicates)
    assert_equal "Big Fern", @fern.display_name(duplicates)
  end

  test "duplicates inside one subdivided area are qualified by spot, not area" do
    # Both would read "Spider Plant (Landing)" if the area were the qualifier.
    shelf = Pot.create!(spot: spots(:landing_shelf), name: "Spider Plant",
                        dry_below: 20, wet_above: 80, check_interval_days: 7)
    corner = Pot.create!(spot: spots(:landing_corner), name: "Spider Plant",
                         dry_below: 20, wet_above: 80, check_interval_days: 7)

    duplicates = Pot.duplicated_names
    assert_equal "Spider Plant (Shelf)", shelf.display_name(duplicates)
    assert_equal "Spider Plant (Far Corner)", corner.display_name(duplicates)
  end

  test "spoken phrasing names the area when it holds one spot" do
    assert_equal "Sunroom Big Fern", @fern.spoken_name
    assert_equal "Put the sensor in the Sunroom Big Fern.", @fern.probe_prompt
  end

  test "spoken phrasing names the spot when the area is subdivided" do
    # Otherwise three "Spider Plant" pots in one room are indistinguishable aloud.
    assert_equal "Shelf Clay Ball Pothos", @pothos.spoken_name
  end

  # --- conditions ---------------------------------------------------------------

  test "a pot whose plants all suit their spot reports no mismatch" do
    assert_not pots(:succulent_bowl).light_mismatch?
    assert_nil pots(:succulent_bowl).light_severity
  end

  test "one step short of the light asked for is marginal" do
    pot = pots(:pothos)   # Landing shelf, effectively medium
    pot.plants.create!(name: "Fussy", light_requirement: "bright")

    assert pot.reload.light_mismatch?
    assert_equal :marginal, pot.light_severity
  end

  test "two steps short is a plant in the wrong place" do
    assert_equal :poor, pots(:orphan).light_severity
    assert_equal [ "Sad Succulent" ], pots(:orphan).underlit_plants.map(&:name)
  end

  test "the worst plant in a shared container speaks for the pot" do
    bowl = pots(:succulent_bowl)          # Sunroom sill, bright
    bowl.plants.create!(name: "Mild", light_requirement: "direct")   # one step short

    assert_equal :marginal, bowl.reload.light_severity

    bowl.spot.update!(natural_light: "low")   # now everything is badly short
    assert_equal :poor, bowl.reload.light_severity
  end

  test "a condition is not a chore" do
    # A mismatch must never leak into #status: watering gets done and goes away,
    # a plant in the wrong place stays wrong until something moves.
    read(pots(:orphan), 60, at: 1.hour.ago)

    assert_equal "fine", pots(:orphan).reload.status
    assert pots(:orphan).light_mismatch?
  end

  private
  def read(pot, value, at:)
    pot.moisture_readings.create!(value: value, read_at: at, source: "test")
  end

  def water(pot, on:)
    pot.care_events.create!(kind: "watered", occurred_on: on)
  end
end
