json.extract! spot, :id, :name, :position, :natural_light, :exposure,
              :grow_light_entity_id, :notes
json.grow_light spot.grow_light?
# What the spot actually provides, grow light included. This is the number
# Plant#light_satisfied? compares against.
json.effective_light spot.effective_light

# Light is decided from DLI. measured_dli when somebody has metered the spot,
# otherwise the figure implied by effective_light.
json.effective_dli spot.effective_dli.to_f
json.measured spot.measured?
json.measured_dli spot.measured_dli&.to_f
json.measured_ppfd spot.measured_ppfd&.to_f
json.light_hours spot.light_hours&.to_f
json.measured_at spot.measured_at
json.full_name spot.full_name
json.area do
  json.id spot.area_id
  json.name spot.area.name
end
json.pot_count spot.pots.size
json.url spot_url(spot, format: :json)
