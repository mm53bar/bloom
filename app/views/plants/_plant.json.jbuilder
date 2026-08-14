json.extract! plant, :id, :name, :species, :light_requirement, :reference_url,
              :acquired_on, :notes
json.light_satisfied plant.light_satisfied?
json.light_shortfall plant.light_shortfall
json.pot do
  json.id plant.pot_id
  json.name plant.pot.name
  json.location plant.location.name
end
json.url plant_url(plant, format: :json)
