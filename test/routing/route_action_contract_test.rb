require "test_helper"

# Every route resolves to an action, and every HTML action has a template.
#
# `config/routes.rb` uses `resources` for collections whose real action surface is
# narrower, and a `resources` line advertises seven verbs whether or not the
# controller implements them. The two failures are different in kind and both are
# invisible until somebody types a URL:
#
#   - A route whose controller has no such action answers `ActionNotFound`, which
#     is a 404 — so `/session/edit` and `/passwords` looked like ordinary pages
#     that had been deleted rather than routes that were never meant to exist.
#   - A route whose action exists but whose template does not answers
#     `ActionController::MissingExactTemplate`, which is a **500**. Four modal-edited
#     content models each carried a `new` action that built an instance variable
#     only a missing `new.html.erb` would have read, so `GET
#     /u/<slug>/characters/new` was a server error rather than a 404.
#
# The distinction is why both halves are asserted here rather than only the first.
# A test that only checked `action_methods` would have passed while all four of
# those `new` actions still existed; a test that only checked for a template would
# have flagged every JSON-only mutation, which correctly renders nothing.
#
# The rule this test encodes: **a route may only advertise an action the controller
# has, and a GET may only name an action with a template.** Mutations answer JSON or
# a redirect and need no template, so the template half is checked per request verb
# rather than per action.
class RouteActionContractTest < ActiveSupport::TestCase
  # `rails/all` mounts Active Storage, Action Mailbox, and Action Text; Turbo and
  # Rails add their own. Those routes belong to the framework, and their controllers
  # resolve to constants that are not defined by this application — see the known
  # quirk about framework routes being broader than the domain. Membership is decided
  # by where a controller's own file lives, not by a name prefix, so a framework route
  # is excluded however it is namespaced.
  APPLICATION_CONTROLLER_DIRECTORY = "app/controllers".freeze

  test "every route resolves to an action its controller implements" do
    offenses = application_routes.filter_map do |route|
      controller = controller_for(route)
      action = route.defaults[:action]
      next unless action
      next if controller.action_methods.include?(action)

      "#{verb(route)} #{route.path.spec} -> #{route.defaults[:controller]}##{action} (no such action)"
    end

    assert_empty offenses, <<~MESSAGE
      These routes name an action their controller does not implement, so a direct
      request answers ActionNotFound (404) rather than anything a reader could have
      meant. Restrict the route with `only:`, or implement the action.

        #{offenses.join("\n  ")}
    MESSAGE
  end

  test "every page route has a template" do
    offenses = application_routes.filter_map do |route|
      next unless page_request?(route)

      controller = route.defaults[:controller]
      action = route.defaults[:action]
      next if template_exists?(controller, action)

      "#{verb(route)} #{route.path.spec} -> #{controller}##{action} (no template)"
    end

    assert_empty offenses, <<~MESSAGE
      These GET routes reach an action with no template, so a direct request answers
      ActionController::MissingExactTemplate — a 500, not a 404. A modal-edited model
      has no `new` or `edit` page and must not advertise one.

        #{offenses.join("\n  ")}
    MESSAGE
  end

  # The route table is a public contract, so the two halves above are held against
  # known routes rather than only against whatever happens to be wrong: a `resources`
  # line silently widened by an edit has to fail even when every action it names
  # happens to exist.
  test "the session and password routes are exactly the ones the flows use" do
    assert_equal %w[ DELETE GET POST ], session_routes
    assert_equal %w[ GET PATCH POST PUT ], password_routes
  end

  test "the modal-edited content models advertise no new or edit page" do
    %w[ characters items locations events ].each do |model|
      verb_names = content_routes(model).map { |route| "#{verb(route)} #{route.path.spec}" }

      assert_empty verb_names.grep(/\/(new|\d+\/edit)/),
        "#{model} advertises a new/edit page it has no template for: #{verb_names.join(', ')}"
    end
  end

  private
    def application_routes
      @application_routes ||= Rails.application.routes.routes.select do |route|
        controller = route.defaults[:controller]
        controller.present? && application_controller?(controller)
      end
    end

    # A controller is the application's own when the constant it resolves to is
    # defined by a file under `app/controllers`. `safe_constantize` alone is not
    # enough: Rails and the frameworks ship real controller classes, so a framework
    # route resolves to a constant just as successfully as one of ours does.
    def application_controller?(name)
      constant = "#{name}_controller".classify.safe_constantize
      return false unless constant

      relative = "#{name}_controller".classify.underscore
      Rails.root.join(APPLICATION_CONTROLLER_DIRECTORY, "#{relative}.rb").exist?
    end

    def controller_for(route)
      "#{route.defaults[:controller]}_controller".classify.safe_constantize
    end

    # A GET renders a page, so it needs a template. Every other verb answers JSON, a
    # redirect, or a head, and renders no template by design — that is what
    # `RequiresJsonMutationFormat` and the HTML redirect flow are.
    def page_request?(route)
      verb(route) == "GET" && route.defaults[:action].present?
    end

    # `.html.erb` for the page, and `.json.jbuilder` counts too: `universes#show` and
    # `#index` serve both formats from one action.
    def template_exists?(controller, action)
      Dir.glob(Rails.root.join("app/views", controller, "#{action}.*")).any?
    end

    def verb(route)
      route.verb.to_s.split("|").first
    end

    def session_routes
      verbs_for { |route| route.defaults[:controller] == "sessions" }
    end

    def password_routes
      verbs_for { |route| route.defaults[:controller] == "passwords" }
    end

    def content_routes(model)
      application_routes.select { |route| route.defaults[:controller] == model }
    end

    def verbs_for
      application_routes.select { |route| yield route }.map { |route| verb(route) }.uniq.sort
    end
end
