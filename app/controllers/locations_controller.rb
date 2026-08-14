class LocationsController < ApplicationController
  before_action :set_location, only: %i[ show edit update destroy ]

  def index
    @locations = Location.in_walk_order.includes(pots: :plants)
  end

  def show
    @pots = @location.pots.with_care_data
  end

  def new
    @location = Location.new
  end

  def edit
  end

  def create
    @location = Location.new(location_params)

    if @location.save
      respond_to do |format|
        format.html { redirect_to @location, notice: "#{@location.name} added." }
        format.json { render :show, status: :created, location: @location }
      end
    else
      render_invalid(:new)
    end
  end

  def update
    if @location.update(location_params)
      respond_to do |format|
        format.html { redirect_to @location, notice: "#{@location.name} updated." }
        format.json { render :show }
      end
    else
      render_invalid(:edit)
    end
  end

  def destroy
    @location.destroy!

    respond_to do |format|
      format.html { redirect_to locations_path, notice: "#{@location.name} removed." }
      format.json { head :no_content }
    end
  end

  private

  def set_location
    @location = Location.find(params[:id])
  end

  def render_invalid(template)
    respond_to do |format|
      format.html { render template, status: :unprocessable_entity }
      format.json { render json: { errors: @location.errors }, status: :unprocessable_entity }
    end
  end

  def location_params
    params.expect(location: [
      :name, :position, :natural_light, :exposure, :grow_light_entity_id, :notes
    ])
  end
end
