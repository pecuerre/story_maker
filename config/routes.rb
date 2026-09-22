Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  resources :universes, param: :universe_slug, path: "u"

  scope "u/:universe_slug", as: :universe do
    resources :section_tags
    resources :sections
    resources :item_tags
    resources :items
    resources :location_tags
    resources :locations
    resources :character_tags
    resources :characters
    resources :relation_tags
    resources :relations, only: %i[ index create update destroy ]
    resources :ownership_tags
    resources :ownerships, only: %i[ index create update destroy ]
    resources :event_tags
    resources :events
    get "timeline", to: "timeline#index", as: :timeline
  end

  get "up" => "rails/health#show", as: :rails_health_check
  root "universes#index"
end
