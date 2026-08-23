class AreasController < ApplicationController
  before_action :set_area, only: %i[ show edit update destroy ]

  def index
    @areas = Area.ordered.includes(spots: { pots: :plants })
  end

  def show
    @spots = @area.spots.includes(pots: :plants)
    @pots = Pot.with_care_data.where(spot: @area.spots).ordered
  end

  def new
    @area = Area.new
  end

  def edit
  end

  def create
    @area = Area.new(area_params)

    if @area.save
      respond_to do |format|
        format.html { redirect_to @area, notice: "#{@area.name} added." }
        format.json { render :show, status: :created, location: @area }
      end
    else
      render_invalid(:new)
    end
  end

  def update
    if @area.update(area_params)
      respond_to do |format|
        format.html { redirect_to @area, notice: "#{@area.name} updated." }
        format.json { render :show }
      end
    else
      render_invalid(:edit)
    end
  end

  def destroy
    @area.destroy!

    respond_to do |format|
      format.html { redirect_to areas_path, notice: "#{@area.name} removed." }
      format.json { head :no_content }
    end
  end

  private

  def set_area
    @area = Area.find(params[:id])
  end

  def render_invalid(template)
    respond_to do |format|
      format.html { render template, status: :unprocessable_entity }
      format.json { render json: { errors: @area.errors }, status: :unprocessable_entity }
    end
  end

  def area_params
    params.expect(area: [ :name, :ha_area, :notes ])
  end
end
