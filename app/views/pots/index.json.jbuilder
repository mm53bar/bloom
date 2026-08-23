# One response an automation can cache in a single sensor and read attributes
# off of, rather than a request per lookup — see docs/home-assistant.md.
json.generated_at Time.current
json.pot_count @pots.size
json.pots @pots, partial: "pots/pot", as: :pot
