json.partial! "moisture_readings/moisture_reading", moisture_reading: @reading
# The point of posting a reading: get the verdict back, already phrased.
json.verdict @pot.spoken_verdict
json.pot do
  json.partial! "pots/pot", pot: @pot
end
