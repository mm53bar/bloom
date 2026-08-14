json.extract! moisture_reading, :id, :pot_id, :read_at, :source
json.value moisture_reading.value.to_f
