# The ordered round through the house. Everything needed to run it is here:
# what to listen for, what to say, where to send the reading, and the
# thresholds that judge it — so no caller has to keep its own plant table.
json.generated_at Time.current
json.pot_count @pots.size

json.pots @pots do |pot|
  json.extract! pot, :id, :name, :medium, :dry_below, :wet_above
  json.aliases pot.voice_aliases
  json.location pot.location.name
  json.prompt pot.probe_prompt
  json.status pot.status
  json.needs_check pot.needs_check?
  json.plants pot.plants.map(&:name)
  json.record_reading_url pot_moisture_readings_url(pot, format: :json)
end
