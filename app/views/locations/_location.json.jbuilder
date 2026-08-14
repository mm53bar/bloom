json.extract! location, :id, :name, :position, :natural_light, :exposure,
              :grow_light_entity_id, :notes
json.grow_light location.grow_light?
json.effective_light location.effective_light
json.pot_count location.pots.size
json.url location_url(location, format: :json)
