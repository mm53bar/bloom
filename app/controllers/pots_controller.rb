class PotsController < ApplicationController
  before_action :set_pot, only: %i[ show edit update destroy watered fertilized ]

  def index
    @pots = roster
  end

  # The ordered route through the house. Everything a voice assistant needs to
  # run a round lives in this one response — names to listen for, phrasing to
  # speak, and the thresholds to judge the reading against.
  def walk
    @pots = roster
  end

  def due
    pots = roster
    @needs_water = pots.select(&:needs_water?)
    @too_wet = pots.select(&:too_wet?)
    @needs_check = pots.select(&:needs_check?)
    @needs_fertilizer = pots.select(&:needs_fertilizer?)
  end

  def show
    @readings = @pot.moisture_readings.recent_first.limit(50)
    @events = @pot.care_events.recent_first.limit(50)
  end

  def new
    @pot = Pot.new(spot: Spot.in_walk_order.first)
  end

  def edit
  end

  def create
    @pot = Pot.new(pot_params)

    if @pot.save
      respond_to do |format|
        format.html { redirect_to @pot, notice: "#{@pot.name} added." }
        format.json { render :show, status: :created, location: @pot }
      end
    else
      render_invalid(:new)
    end
  end

  def update
    if @pot.update(pot_params)
      respond_to do |format|
        format.html { redirect_to @pot, notice: "#{@pot.name} updated." }
        format.json { render :show }
      end
    else
      render_invalid(:edit)
    end
  end

  def destroy
    @pot.destroy!

    respond_to do |format|
      format.html { redirect_to pots_path, notice: "#{@pot.name} removed." }
      format.json { head :no_content }
    end
  end

  def watered = record_care("watered")
  def fertilized = record_care("fertilized")

  private

  def roster = Pot.with_care_data.in_walk_order.to_a

  def record_care(kind)
    @pot.care_events.create!(
      kind: kind,
      occurred_on: params[:occurred_on].presence || Date.current,
      product: params[:product],
      note: params[:note]
    )
    @pot.reload

    respond_to do |format|
      format.html { redirect_back fallback_location: @pot, notice: "Recorded: #{kind}." }
      format.json { render :show }
    end
  end

  def set_pot
    @pot = Pot.with_care_data.find(params[:id])
  end

  def render_invalid(template)
    respond_to do |format|
      format.html { render template, status: :unprocessable_entity }
      format.json { render json: { errors: @pot.errors }, status: :unprocessable_entity }
    end
  end

  def pot_params
    params.expect(pot: [
      :spot_id, :name, :medium, :dry_below, :wet_above,
      :water_interval_days, :fertilize_interval_days, :check_interval_days,
      :position, :potted_on, :notes, :voice_alias_list, { voice_aliases: [] }
    ])
  end
end
