Rails.application.routes.draw do
  resources :packagings
  resources :entities do
    get :new_address, on: :collection
    resources :customs_agent_patents, only: [ :create, :update, :destroy, :edit ]
    resources :addresses, controller: "entity_addresses", only: [ :create, :update, :destroy, :edit ]
  end
  resources :ports
  devise_for :users

  resources :shipping_lines
  resources :vessels
  resources :consolidators
  resources :containers
  resources :bl_house_lines

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
