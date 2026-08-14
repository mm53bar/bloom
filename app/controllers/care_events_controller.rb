class CareEventsController < ApplicationController
  before_action :set_pot

  # As with readings: the pot page carries the timeline, so HTML redirects there
  # and this exists for callers that want the whole series.
  def index
    @events = @pot.care_events.recent_first.limit(200)

    respond_to do |format|
      format.html { redirect_to @pot }
      format.json
    end
  end

  # The general path. Watering and feeding also have shortcut routes on Pot,
  # since those are the two a voice assistant records constantly.
  def create
    @event = @pot.care_events.new(event_params)

    if @event.save
      @pot.reload

      respond_to do |format|
        format.html { redirect_to @pot, notice: "Recorded: #{@event}." }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to @pot, alert: @event.errors.full_messages.to_sentence }
        format.json { render json: { errors: @event.errors }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_pot
    @pot = Pot.with_care_data.find(params[:pot_id])
  end

  def event_params
    params.expect(care_event: [ :kind, :occurred_on, :product, :note ])
  end
end
