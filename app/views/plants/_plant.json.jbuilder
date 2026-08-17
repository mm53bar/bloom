json.extract! plant, :id, :name, :species, :light_requirement, :reference_url,
              :acquired_on, :notes
json.light_satisfied plant.light_satisfied?
json.light_severity plant.light_severity
json.dli_required plant.dli_required.to_f
json.dli_available plant.spot.effective_dli.to_f
json.dli_measured plant.spot.measured?
json.light_deficit plant.light_deficit.to_f
json.pot do
  json.id plant.pot_id
  json.name plant.pot.name
  json.spot plant.spot.full_name
  json.area plant.area.name
end
json.url plant_url(plant, format: :json)
