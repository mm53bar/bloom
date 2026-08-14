json.extract! pot, :id, :name, :medium, :dry_below, :wet_above,
              :water_interval_days, :fertilize_interval_days, :check_interval_days,
              :position, :potted_on, :notes

json.aliases pot.voice_aliases

json.spot do
  json.id pot.spot_id
  json.name pot.spot.name
  json.full_name pot.spot.full_name
  json.effective_light pot.spot.effective_light
end

json.area do
  json.id pot.area.id
  json.name pot.area.name
end

# Verdicts, so a caller never needs its own copy of the thresholds.
json.status pot.status
json.needs_water pot.needs_water?
json.too_wet pot.too_wet?
json.needs_check pot.needs_check?
json.needs_fertilizer pot.needs_fertilizer?

json.last_watered_on pot.last_watered_on
json.last_fertilized_on pot.last_fertilized_on

if pot.latest_reading
  json.latest_reading do
    json.value pot.latest_reading.value.to_f
    json.read_at pot.latest_reading.read_at
    json.source pot.latest_reading.source
    json.fresh pot.reading_fresh?
  end
else
  json.latest_reading nil
end

json.plants pot.plants do |plant|
  json.extract! plant, :id, :name, :species, :light_requirement
  json.light_satisfied plant.light_satisfied?
end

json.url pot_url(pot, format: :json)
