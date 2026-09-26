Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  resources :universes, param: :universe_slug, path: "u"

  scope "u/:universe_slug", as: :universe do
    resources :stories, path: "s" do
      resources :sections
      resources :section_tags
      resources :scene_tags
      resources :scenes do
        patch :move, on: :member
        # Collection action: the Section workspace submits the chosen scene and
        # the chosen group together, so grouping needs no client-side scripting.
        patch :group, on: :collection
        # Elements live under Scene Details rather than on a page of their own,
        # so this collection only mutates. Their dialogue speakers travel in the
        # same payload; there is no separate speaker route.
        resources :scene_elements, path: "elements", only: %i[ create update destroy ] do
          patch :move, on: :member
        end
        # The Characters tab is its own canonical page. Only the role is editable
        # afterwards: a link is added, given a role, or removed.
        resources :scene_characters, path: "characters", only: %i[ index create update destroy ]
      end
    end
    get "tags", to: "tags#index", as: :tags
    resources :item_tags
    resources :items
    resources :location_tags
    resources :locations
    resources :character_tags
    resources :characters
    resources :relation_tags
    # Relations and Ownerships are link records between two entities; they have a
    # read-only details page but no separate editor.
    resources :relations, only: %i[ index show create update destroy ]
    resources :ownership_tags
    resources :ownerships, only: %i[ index show create update destroy ]
    resources :memberships, only: %i[ index new create update destroy ], path: "members"
    resources :event_tags
    resources :events
    get "timeline", to: "timeline#index", as: :timeline
  end

  get "up" => "rails/health#show", as: :rails_health_check
  root "universes#index"
end
