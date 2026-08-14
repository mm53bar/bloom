json.extract! spot, :id, :name, :position, :natural_light, :exposure,
              :grow_light_entity_id, :notes
json.grow_light spot.grow_light?
# What the spot actually provides, grow light included. This is the number
# Plant#light_satisfied? compares against.
json.effective_light spot.effective_light
json.full_name spot.full_name
json.area do
  json.id spot.area_id
  json.name spot.area.name
end
json.pot_count spot.pots.size
json.url spot_url(spot, format: :json)
