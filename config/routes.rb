Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  resources :stories, param: :story_slug, path: "s"

  scope "s/:story_slug", as: :story do
    resources :section_types
    resources :sections
  end

  get "up" => "rails/health#show", as: :rails_health_check
  root "stories#index"
end
