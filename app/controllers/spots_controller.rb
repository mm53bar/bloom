class SpotsController < ApplicationController
  before_action :set_area, only: %i[ new create ]
  before_action :set_spot, only: %i[ show edit update destroy ]

  def show
    @pots = @spot.pots.with_care_data
  end

  def new
    @spot = @area.spots.new(natural_light: @area.default_spot&.natural_light || "medium")
  end

  def edit
  end

  def create
    @spot = @area.spots.new(spot_params)

    if @spot.save
      respond_to do |format|
        format.html { redirect_to @area, notice: "#{@spot.name} added to #{@area.name}." }
        format.json { render :show, status: :created, location: @spot }
      end
    else
      render_invalid(:new)
    end
  end

  def update
    if @spot.update(spot_params)
      respond_to do |format|
        format.html { redirect_to @spot.area, notice: "#{@spot.name} updated." }
        format.json { render :show }
      end
    else
      render_invalid(:edit)
    end
  end

  def destroy
    area = @spot.area
    @spot.destroy!

    respond_to do |format|
      format.html { redirect_to area, notice: "#{@spot.name} removed." }
      format.json { head :no_content }
    end
  end

  private

  def set_area
    @area = Area.find(params[:area_id])
  end

  def set_spot
    @spot = Spot.includes(:area).find(params[:id])
  end

  def render_invalid(template)
    respond_to do |format|
      format.html { render template, status: :unprocessable_entity }
      format.json { render json: { errors: @spot.errors }, status: :unprocessable_entity }
    end
  end

  # area_id is permitted so a spot can move between areas. Rooms get reorganised,
  # and without this the only way to correct a misfiled spot is to delete it — which
  # cascades to its pots and their entire history.
  def spot_params
    params.expect(spot: [
      :area_id, :name, :position, :natural_light, :exposure, :grow_light_entity_id,
      :measured_dli, :measured_ppfd, :light_hours, :measured_at, :notes
    ])
  end
end
