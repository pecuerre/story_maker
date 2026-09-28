Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  # Platform settings are not universe-scoped: a theme belongs to the browser,
  # so the page is reachable before a universe is chosen and by a guest.
  resource :settings, only: %i[ show update ]

  resources :universes, param: :universe_slug, path: "u"

  # The top-bar search. It is a read with no page of its own per resource, so it
  # is a `get` rather than a `resources` collection: a route advertising actions
  # that do not exist is exactly the known-quirk this avoids. The platform form
  # is the default, and the nested one keeps a universe-scoped search inside the
  # universe's own URL, where the shared universe callbacks resolve and
  # authorize the scope.
  get "search", to: "searches#show", as: :search

  scope "u/:universe_slug", as: :universe do
    get "search", to: "searches#show", as: :search

    resources :stories, path: "s" do
      resources :sections
      resources :section_tags, only: %i[ index show create update destroy ]
      resources :scene_tags, only: %i[ index show create update destroy ]
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
        # Items and Locations follow the same read-page/JSON-mutation contract.
        # The Locations tab is plural because a Scene may use any number of them.
        resources :scene_items, path: "items", only: %i[ index create update destroy ]
        resources :scene_locations, path: "locations", only: %i[ index create update destroy ]
      end
    end
    get "tags", to: "tags#index", as: :tags
    resources :item_tags, only: %i[ index show create update destroy ]
    resources :items
    resources :location_tags, only: %i[ index show create update destroy ]
    resources :locations
    resources :character_tags, only: %i[ index show create update destroy ]
    resources :characters
    resources :relation_tags, only: %i[ index show create update destroy ]
    # Relations and Ownerships are link records between two entities; they have a
    # read-only details page but no separate editor.
    resources :relations, only: %i[ index show create update destroy ]
    resources :ownership_tags, only: %i[ index show create update destroy ]
    resources :ownerships, only: %i[ index show create update destroy ]
    resources :memberships, only: %i[ index new create update destroy ], path: "members"
    resources :event_tags, only: %i[ index show create update destroy ]
    resources :events
    get "timeline", to: "timeline#index", as: :timeline
  end

  get "up" => "rails/health#show", as: :rails_health_check
  root "universes#index"
end
