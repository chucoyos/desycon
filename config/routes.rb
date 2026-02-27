Rails.application.routes.draw do
  get "customs_agents/dashboard"
  get "customs_agents/revalidations", to: "customs_agents#revalidation_modal", as: :customs_agents_revalidation
  patch "customs_agents/revalidations/:id", to: "customs_agents#revalidation_update", as: :customs_agents_revalidation_update

  devise_for :users, skip: :all

  devise_scope :user do
    # Sessions
    get    "users/sign_in",  to: redirect("/"),             as: :new_user_session
    post   "users/sign_in",  to: "devise/sessions#create",  as: :user_session
    delete "users/sign_out", to: "devise/sessions#destroy", as: :destroy_user_session

    # Registrations (disabled)
    get "users/sign_up", to: redirect("/"), as: :new_user_registration

    # Password recovery
    get   "users/password/new",  to: "devise/passwords#new",    as: :new_user_password
    post  "users/password",      to: "devise/passwords#create", as: :user_password
    get   "users/password/edit", to: "devise/passwords#edit",   as: :edit_user_password
    patch "users/password",      to: "devise/passwords#update"
    put   "users/password",      to: "devise/passwords#update"
  end

  resources :notifications, only: [ :index, :destroy ] do
    member do
      patch :mark_as_read
    end
  end

  resources :photos, only: [ :destroy ]

  resources :revalidations, only: [ :show ]

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
    resources :agency_brokers, only: [ :create, :destroy ]
    resources :addresses, controller: "entity_addresses", only: [ :create, :update, :destroy, :edit ]
  end
  resources :ports

  resources :shipping_lines
  resources :vessels
  resources :voyages
  resources :consolidators
  resources :containers do
    member do
      post :photos, to: "photos#create_for_container"
    end

    member do
      delete :destroy_all_bl_house_lines
      post :import_bl_house_lines, to: "bl_house_lines#import_from_container"
      get :lifecycle_bl_master_modal
      patch :lifecycle_bl_master_update
      get :lifecycle_descarga_modal
      patch :lifecycle_descarga_update
      get :lifecycle_transferencia_modal
      patch :lifecycle_transferencia_update
      get :lifecycle_tentativa_modal
      patch :lifecycle_tentativa_update
      get :lifecycle_tarja_modal
      patch :lifecycle_tarja_update
    end
  end
  resources :bl_house_lines do
    member do
      post :photos, to: "photos#create_for_bl_house_line"
    end

    member do
      get :revalidation_approval
      patch :approve_revalidation
      get :documents
      get :reassign
      patch :perform_reassign
      get :reassign_brokers
      get :dispatch_date
      patch :update_dispatch_date
    end
  end
  resources :service_catalogs

  get "blocked", to: "blocked_users#show", as: :blocked_users

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"

  # Catch-all for unmatched routes (skip ActiveStorage and built-in rails paths)
  match "*unmatched", to: "application#not_found", via: :all, constraints: lambda { |req|
    !req.path.start_with?("/rails/active_storage")
  }
end
