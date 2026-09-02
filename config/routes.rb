Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  resources :stories, param: :slug, path: "s" do
    resources :section_types
  end

  get "up" => "rails/health#show", as: :rails_health_check
  root "stories#index"
end
