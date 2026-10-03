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
    # One conversation per record. `show` is a guest-readable read of an
    # append-only thread; it never creates anything. The "Discuss" control on a
    # record's details page POSTs to `create`, which finds or creates the thread
    # and redirects to it, so no GET ever writes. Replies post to their own
    # nested action rather than to the thread's `show`.
    resources :discussions, only: %i[ show create ] do
      resources :messages, only: :create, controller: "messages"
    end
    resources :event_tags, only: %i[ index show create update destroy ]
    resources :events
    get "timeline", to: "timeline#index", as: :timeline
    # One author's remembered changes for this universe. `apply` and `discard`
    # are two POSTs rather than a `resources` verb list: each is a decision the
    # author makes about their own pending work, and neither is idempotent — an
    # `apply` writes records, and a `discard` closes the draft. Both answer with
    # a redirect, as the HTML flow requires. The page has no `create` or
    # `destroy` because a draft is opened by the remembering path
    # (`Draft.open_for!`) and is never deleted, only moved to another status.
    resources :drafts, only: %i[ index show ] do
      post :apply, on: :member
      post :discard, on: :member
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
  root "universes#index"
end
