Rails.application.routes.draw do
  # Only the three actions the sign-in flow has: a form, a submit, and a sign-out.
  # `resource :session` on its own also advertises `show`, `edit`, and `update`,
  # none of which exists — a route whose action is missing answers 404 rather than
  # anything a reader could have meant.
  resource :session, only: %i[ new create destroy ]
  # A password reset is a form, a submit, and a token-addressed form pair. `index`
  # and `show` would be a list of every outstanding token and a page reading one,
  # which is not a thing this application offers; `destroy` would revoke a reset
  # without a session to revoke it against.
  resources :passwords, param: :token, only: %i[ new create edit update ]
  # Platform settings are not universe-scoped: a theme belongs to the browser,
  # so the page is reachable before a universe is chosen and by a guest.
  resource :settings, only: %i[ show update ]

  # What happened to you while you were elsewhere, and the one page that lists it.
  # Also not universe-scoped, and deliberately so: a notification carries its own
  # universe's slug in its payload, so the navbar can show a reader something from
  # a universe they are not currently inside, and a bell scoped to one universe
  # could not answer for the others.
  #
  # `read` and `read_all` are POSTs rather than a PATCH because they are the only
  # two writes here and neither is idempotent in the sense a `PATCH` claims to be:
  # marking one notification read twice is not an error but it is not the same
  # request either, and a GET that marked a row read would let a link, a prefetch,
  # or a crawler silently answer a bell on the reader's behalf.
  resources :notifications, only: %i[ index ] do
    post :read, on: :member
    post :read_all, on: :collection
  end

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
      # A Section is created and edited through the JSON modal on the Sections
      # workspace, so it has the same five actions as the other content models and
      # no `new`/`edit` page — see the Characters resource below.
      resources :sections, only: %i[ index show create update destroy ]
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
    # The four modal-edited content models below all have the same five actions:
    # `index`/`show` are the two reads, and create/update/destroy are the JSON
    # mutations the workspace's modal issues. There is deliberately no `new` or
    # `edit` page for any of them — the modal holds the form — so advertising
    # those routes would answer a request with a missing-template error rather
    # than with anything. `new` used to exist here as a bare `@record` builder
    # with no template; the `parent_id` it read is still accepted by `create`.
    resources :items, only: %i[ index show create update destroy ]
    resources :location_tags, only: %i[ index show create update destroy ]
    resources :locations, only: %i[ index show create update destroy ]
    resources :character_tags, only: %i[ index show create update destroy ]
    resources :characters, only: %i[ index show create update destroy ]
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
    # An Event is modal-edited like the four above, and its `new` action built a
    # `@events_for_select` collection that only its missing template read.
    resources :events, only: %i[ index show create update destroy ]
    get "timeline", to: "timeline#index", as: :timeline
    # One author's remembered changes for this universe. `apply`, `submit`, and
    # `discard` are three POSTs rather than a `resources` verb list: each is a
    # decision the author makes about their own pending work, and none of them is
    # idempotent — an `apply` writes records, a `submit` hands the draft over to a
    # reviewer, and a `discard` closes the draft. All three answer with a redirect,
    # as the HTML flow requires. `submit` is the `github`-mode one and carries the
    # author's optional message; `apply` is what the other draft-based mode does
    # instead, and each refuses the other mode's answer rather than only hiding the
    # control. The page has no `create` or `destroy` because a draft is opened by
    # the remembering path (`Draft.open_for!`) and is never deleted, only moved to
    # another status.
    resources :drafts, only: %i[ index show ] do
      post :apply, on: :member
      post :submit, on: :member
      post :discard, on: :member
    end
    # What a reviewer answers: somebody else's submitted draft, and the one
    # decision that can be made about it. `approve` and `reject` are POSTs for
    # the reason `apply` and `discard` are: an approval writes every remembered
    # change and a rejection closes the submission, and neither is idempotent.
    # `approve` is also the action a conflict page posts back to, so it is
    # reached twice on that journey. Every action here asks for `admin` on the
    # universe, so the reader queue is the owner and the admins and nobody else.
    resources :review_requests, only: %i[ index show ] do
      post :approve, on: :member
      post :reject, on: :member
    end
    # What happened to this universe's content: every closed draft, grouped by the day
    # it closed. A `get` and not a `resources` collection, because there is one page
    # and no member of its own to address — the drafts it lists already have theirs.
    # It asks for `admin` on the universe, like the review queue, because it reads
    # every author's work rather than the reader's own pending work.
    get "history", to: "histories#index", as: :history
    # Who has changed this universe, and what one of them changed. Two reads rather
    # than one page with a filter: the sidebar figure has to count people and the
    # list's own figure has to count changes, and a filtered universe-wide page would
    # have to be right about both in its chrome. The per-person page is the change
    # history narrowed to an author, and it asks for `admin` like the history it reuses.
    resources :collaborators, only: %i[ index show ]
    # Whether this reader is editing this universe right now. It is a session
    # claim rather than a record, so it is a singleton `resource` with the two
    # verbs that begin and end one — the same shape `resource :session` uses for
    # signing in and out. It deliberately has no `show`: the universe page renders
    # the current state, and a GET that mutates nothing must not be a way to start
    # one. Neither action decides whether a mutation is remembered; `DraftMutation`
    # does that, in a draft-based universe, on every request (ADR 0022).
    resource :editing, controller: "draft_editing", only: %i[ create destroy ], path: "editing"
  end

  # The external-tool surface. It is JSON-only, authenticated by a bearer token
  # rather than a session, and every route stays inside a universe scope.
  namespace :api do
    scope "u/:universe_slug", as: :universe do
      resources :characters, only: %i[ index show create update destroy ]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
  root "universes#index"
end
