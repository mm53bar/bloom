json.partial! "areas/area", area: @area
json.spots @area.spots, partial: "spots/spot", as: :spot
