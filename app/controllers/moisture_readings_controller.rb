class MoistureReadingsController < ApplicationController
  before_action :set_pot

  # History, for callers that want the series. The pot page already shows recent
  # readings inline, so the HTML side just goes there.
  def index
    @readings = @pot.moisture_readings.recent_first.limit(200)

    respond_to do |format|
      format.html { redirect_to @pot }
      format.json
    end
  end

  # Where a reading lands after someone walks the probe round the house. The
  # response carries the verdict as well as the record, so the caller never has
  # to hold a copy of this pot's thresholds to decide what to say.
  def create
    @reading = @pot.moisture_readings.new(reading_params)

    if @reading.save
      @pot.reload

      respond_to do |format|
        format.html { redirect_to @pot, notice: @pot.spoken_verdict }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to @pot, alert: @reading.errors.full_messages.to_sentence }
        format.json { render json: { errors: @reading.errors }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_pot
    @pot = Pot.with_care_data.find_by!(slug: params[:pot_id])
  end

  def reading_params
    params.expect(moisture_reading: [ :value, :read_at, :source ])
  end
end
