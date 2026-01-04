Rails.application.routes.draw do
  get "customs_agents/dashboard"
  get "customs_agents/revalidations", to: "customs_agents#revalidation_modal", as: :customs_agents_revalidation
  patch "customs_agents/revalidations/:id", to: "customs_agents#revalidation_update", as: :customs_agents_revalidation_update

  devise_for :users, skip: :all

  devise_scope :user do
    # Sessions
    get    "users/sign_in",  to: "devise/sessions#new",     as: :new_user_session
    post   "users/sign_in",  to: "devise/sessions#create",  as: :user_session
    delete "users/sign_out", to: "devise/sessions#destroy", as: :destroy_user_session

    # Registrations
    get    "users/sign_up", to: "devise/registrations#new",    as: :new_user_registration
    post   "users",         to: "devise/registrations#create", as: :user_registration
    get    "users/edit",    to: "devise/registrations#edit",   as: :edit_user_registration
    patch  "users",         to: "devise/registrations#update"
    put    "users",         to: "devise/registrations#update"
    delete "users",         to: "devise/registrations#destroy"

    # Password recovery
    get   "users/password/new",  to: "devise/passwords#new",    as: :new_user_password
    post  "users/password",      to: "devise/passwords#create", as: :user_password
    get   "users/password/edit", to: "devise/passwords#edit",   as: :edit_user_password
    patch "users/password",      to: "devise/passwords#update"
    put   "users/password",      to: "devise/passwords#update"
  end

  resources :packagings
  resources :roles do
    member do
      get :permissions
      patch :permissions, action: :update_permissions
    end
  end

  namespace :admin do
    resources :users
  end

  resources :entities do
    get :new_address, on: :collection
    resources :customs_agent_patents, only: [ :index, :new, :create, :update, :destroy, :edit ]
    resources :addresses, controller: "entity_addresses", only: [ :create, :update, :destroy, :edit ]
  end
  resources :ports

  resources :shipping_lines
  resources :vessels
  resources :consolidators
  resources :containers
  resources :bl_house_lines
  resources :service_catalogs

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
