# An invented household, so a fresh install has something to look at. Nothing in
# here describes a real home — see db/seeds.rb.
namespace :bloom do
  DEMO_LOCATIONS = [
    { name: "Sunroom", position: 1, natural_light: "bright",
      exposure: "South-facing glass on three sides" },
    { name: "Landing", position: 2, natural_light: "low",
      exposure: "No window of its own; borrowed light from the stairwell",
      grow_light_entity_id: "switch.example_grow_light" },
    { name: "Study", position: 3, natural_light: "medium",
      exposure: "East window, desk height" }
  ].freeze

  DEMO_POTS = [
    { location: "Sunroom", name: "Big Fern", position: 1, medium: "soil",
      voice_aliases: [ "the big fern" ], dry_below: 30, wet_above: 80,
      water_interval_days: 7, fertilize_interval_days: 30, check_interval_days: 7,
      plants: [ { name: "Boston Fern", species: "Nephrolepis exaltata", light_requirement: "medium" } ] },

    { location: "Sunroom", name: "Succulent Bowl", position: 2, medium: "soil",
      voice_aliases: [ "the succulents" ], dry_below: 15, wet_above: 95,
      water_interval_days: 21, check_interval_days: 14,
      plants: [
        { name: "Jade", species: "Crassula ovata", light_requirement: "bright" },
        { name: "Echeveria", species: "Echeveria elegans", light_requirement: "bright" }
      ] },

    { location: "Landing", name: "Clay Ball Pothos", position: 1, medium: "semi_hydro",
      dry_below: 20, wet_above: 100, water_interval_days: 14, check_interval_days: 14,
      plants: [ { name: "Golden Pothos", species: "Epipremnum aureum", light_requirement: "low" } ] },

    { location: "Study", name: "Desk Fig", position: 1, medium: "soil",
      dry_below: 25, wet_above: 85, water_interval_days: 10,
      fertilize_interval_days: 21, check_interval_days: 7,
      plants: [ { name: "Fiddle Leaf Fig", species: "Ficus lyrata", light_requirement: "bright" } ] }
  ].freeze

  desc "Load an invented household so the app has something in it"
  task demo: :environment do
    DEMO_LOCATIONS.each do |attributes|
      Location.find_or_create_by!(name: attributes[:name]).update!(attributes)
    end

    DEMO_POTS.each do |attributes|
      plants = attributes[:plants]
      location = Location.find_by!(name: attributes[:location])

      pot = Pot.find_or_initialize_by(name: attributes[:name])
      pot.update!(attributes.except(:location, :plants).merge(location: location))

      plants.each do |plant|
        pot.plants.find_or_initialize_by(name: plant[:name]).update!(plant)
      end

      # A little history, so the due and walk pages have something to say.
      pot.care_events.find_or_create_by!(kind: "watered", occurred_on: 9.days.ago.to_date)
      pot.moisture_readings.find_or_create_by!(source: "demo") do |reading|
        reading.value = rand(8..70)
        reading.read_at = rand(1..12).days.ago
      end
    end

    puts "Loaded #{Location.count} locations, #{Pot.count} pots, #{Plant.count} plants."
  end

  desc "Remove everything the demo task created"
  task undemo: :environment do
    Location.where(name: DEMO_LOCATIONS.map { |l| l[:name] }).destroy_all
    puts "Demo data removed."
  end
end
