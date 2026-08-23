# An invented household, so a fresh install has something to look at. Nothing in
# here describes a real home — see db/seeds.rb.
namespace :bloom do
  # An area is a part of the house; a spot is where in it a pot actually sits.
  # The Landing has two spots on purpose: same room, very different light.
  DEMO_AREAS = [
    { name: "Sunroom", spots: [
      { name: "Window Sill", natural_light: "bright",
        exposure: "South-facing glass on three sides" }
    ] },
    { name: "Landing", spots: [
      { name: "Shelf", natural_light: "low",
        exposure: "No window of its own; borrowed light from the stairwell",
        grow_light_entity_id: "switch.example_grow_light" },
      { name: "Far Corner", natural_light: "low",
        exposure: "Across the landing from the shelf, nothing over it" }
    ] },
    { name: "Study", spots: [
      { name: "Desk", natural_light: "medium",
        exposure: "East window, desk height" }
    ] }
  ].freeze

  DEMO_POTS = [
    { spot: [ "Sunroom", "Window Sill" ], name: "Big Fern", medium: "soil",
      voice_aliases: [ "the big fern" ], dry_below: 30, wet_above: 80,
      water_interval_days: 7, fertilize_interval_days: 30, check_interval_days: 7,
      plants: [ { name: "Boston Fern", species: "Nephrolepis exaltata", light_requirement: "medium" } ] },

    { spot: [ "Sunroom", "Window Sill" ], name: "Succulent Bowl", medium: "soil",
      voice_aliases: [ "the succulents" ], dry_below: 15, wet_above: 95,
      water_interval_days: 21, check_interval_days: 14,
      plants: [
        { name: "Jade", species: "Crassula ovata", light_requirement: "bright" },
        { name: "Echeveria", species: "Echeveria elegans", light_requirement: "bright" }
      ] },

    { spot: [ "Landing", "Shelf" ], name: "Clay Ball Pothos", medium: "semi_hydro",
      dry_below: 20, wet_above: 100, water_interval_days: 14, check_interval_days: 14,
      plants: [ { name: "Golden Pothos", species: "Epipremnum aureum", light_requirement: "low" } ] },

    { spot: [ "Study", "Desk" ], name: "Desk Fig", medium: "soil",
      dry_below: 25, wet_above: 85, water_interval_days: 10,
      fertilize_interval_days: 21, check_interval_days: 7,
      plants: [ { name: "Fiddle Leaf Fig", species: "Ficus lyrata", light_requirement: "bright" } ] }
  ].freeze

  desc "Load an invented household so the app has something in it"
  task demo: :environment do
    DEMO_AREAS.each do |attributes|
      area = Area.find_or_create_by!(name: attributes[:name])
      area.update!(attributes.except(:spots))

      attributes[:spots].each do |spot_attributes|
        # find_or_initialize because creating an area already made one spot.
        spot = area.spots.find_or_initialize_by(name: spot_attributes[:name])
        spot.update!(spot_attributes)
      end

      # Drop the auto-created default spot if the demo named its spots differently.
      area.spots.reload.reject { |spot|
        attributes[:spots].any? { |s| s[:name] == spot.name }
      }.each { |spot| spot.destroy! if spot.pots.empty? }
    end

    DEMO_POTS.each do |attributes|
      plants = attributes[:plants]
      area_name, spot_name = attributes[:spot]
      spot = Area.find_by!(name: area_name).spots.find_by!(name: spot_name)

      pot = Pot.find_or_initialize_by(name: attributes[:name])
      pot.update!(attributes.except(:spot, :plants).merge(spot: spot))

      plants.each do |plant|
        pot.plants.find_or_initialize_by(name: plant[:name]).update!(plant)
      end

      # A little history, so the pot list and due page have something to say.
      pot.care_events.find_or_create_by!(kind: "watered", occurred_on: 9.days.ago.to_date)
      pot.moisture_readings.find_or_create_by!(source: "demo") do |reading|
        reading.value = rand(8..70)
        reading.read_at = rand(1..12).days.ago
      end
    end

    puts "Loaded #{Area.count} areas, #{Spot.count} spots, #{Pot.count} pots, #{Plant.count} plants."
  end

  desc "Remove everything the demo task created"
  task undemo: :environment do
    Area.where(name: DEMO_AREAS.map { |a| a[:name] }).destroy_all
    puts "Demo data removed."
  end
end
