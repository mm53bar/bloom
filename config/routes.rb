Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root "pots#index"

  # Ordinary resourceful routes, HTML and JSON off the same URLs (format
  # negotiated). The JSON side is what Home Assistant and the data loader talk
  # to — there is no separate /api namespace to keep in sync.
  resources :locations
  resources :plants

  resources :pots do
    member do
      # Shortcuts for the two things a voice assistant needs to record.
      post :watered
      post :fertilized
    end

    collection do
      # The ordered route through the house, with the phrasing to speak at each
      # stop. One request replaces a hardcoded plant list in the automation.
      get :walk
      # What wants attention right now, and why.
      get :due
    end

    resources :moisture_readings, only: [ :index, :create ]
    resources :care_events, only: [ :index, :create ]
  end
end
