class PlantsController < ApplicationController
  before_action :set_plant, only: %i[ show edit update destroy ]

  def index
    @plants = Plant.includes(pot: :location).by_name
    # The point of tracking light at all: plants asking for more than their spot
    # provides. Cheap to compute, and it's the one report that suggests moving
    # a plant rather than watering it.
    @underlit = @plants.reject(&:light_satisfied?)
  end

  def show
  end

  def new
    @plant = Plant.new(pot_id: params[:pot_id])
  end

  def edit
  end

  def create
    @plant = Plant.new(plant_params)

    if @plant.save
      respond_to do |format|
        format.html { redirect_to @plant.pot, notice: "#{@plant.name} added." }
        format.json { render :show, status: :created, location: @plant }
      end
    else
      render_invalid(:new)
    end
  end

  def update
    if @plant.update(plant_params)
      respond_to do |format|
        format.html { redirect_to @plant, notice: "#{@plant.name} updated." }
        format.json { render :show }
      end
    else
      render_invalid(:edit)
    end
  end

  def destroy
    pot = @plant.pot
    @plant.destroy!

    respond_to do |format|
      format.html { redirect_to pot, notice: "#{@plant.name} removed." }
      format.json { head :no_content }
    end
  end

  private

  def set_plant
    @plant = Plant.includes(pot: :location).find(params[:id])
  end

  def render_invalid(template)
    respond_to do |format|
      format.html { render template, status: :unprocessable_entity }
      format.json { render json: { errors: @plant.errors }, status: :unprocessable_entity }
    end
  end

  def plant_params
    params.expect(plant: [
      :pot_id, :name, :species, :light_requirement, :reference_url, :acquired_on, :notes
    ])
  end
end
