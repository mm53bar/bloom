class ProbesController < ApplicationController
  # What the probe says right now, for filling in a reading by hand. Nothing is
  # recorded here — the person still checks the number and presses Record.
  def show
    reading = Probe.read

    render json: { value: reading.value, reported_at: reading.reported_at.iso8601 }
  rescue Probe::Unavailable => error
    render json: { error: error.message }, status: :service_unavailable
  end
end
