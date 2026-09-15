Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  resources :universes, param: :universe_slug, path: "u"

  scope "u/:universe_slug", as: :universe do
    resources :section_types
    resources :sections
    resources :item_types
    resources :items
    resources :location_types
    resources :locations
    resources :character_types
    resources :characters
    resources :relation_types
    resources :relations, only: %i[ index create update destroy ]
    resources :ownership_types
    resources :ownerships, only: %i[ index create update destroy ]
    resources :event_types
    resources :events
    get "timeline", to: "timeline#index", as: :timeline
  end

  get "up" => "rails/health#show", as: :rails_health_check
  root "universes#index"
end
