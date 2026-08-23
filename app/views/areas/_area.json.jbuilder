json.extract! area, :id, :name, :ha_area, :notes
json.single_spot area.single_spot?
json.spot_count area.spots.size
json.pot_count area.pots.size
json.url area_url(area, format: :json)
