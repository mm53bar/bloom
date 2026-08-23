json.generated_at Time.current

json.counts do
  json.needs_water @needs_water.size
  json.too_wet @too_wet.size
  json.needs_check @needs_check.size
  json.needs_fertilizer @needs_fertilizer.size
end

{ needs_water: @needs_water, too_wet: @too_wet,
  needs_check: @needs_check, needs_fertilizer: @needs_fertilizer }.each do |key, pots|
  json.set! key do
    json.array! pots do |pot|
      json.extract! pot, :id, :slug, :name
      json.display_name pot.display_name
      json.area pot.area.name
      json.spot pot.spot.full_name
      json.status pot.status
      json.url pot_url(pot, format: :json)
    end
  end
end
