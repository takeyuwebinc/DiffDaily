Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "posts#index"

  resources :posts, only: [ :index, :show ]

  # API routes
  namespace :api do
    resource :link_cards, only: [] do
      get :metadata, on: :collection
    end
  end

  # OmniAuth callback routes
  get "/auth/:provider/callback", to: "admin/omniauth_callbacks#google_oauth2", as: :omniauth_callback
  get "/auth/failure", to: "admin/omniauth_callbacks#failure"

  # Admin routes
  namespace :admin do
    get "login", to: "sessions#new"
    delete "logout", to: "sessions#destroy"

    root "dashboards#show"

    resources :repositories, only: [ :index, :new, :create, :destroy ]
  end
end
