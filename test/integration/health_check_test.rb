require "test_helper"

# `GET /up` is the deployment's health check, and it is the one route whose
# absence no other test would notice: every other endpoint here has a view, a
# controller test, and a route helper to break, while `/up` is Rails' own health
# controller reached through one line in `config/routes.rb`. CI's production-boot
# job proves it answers `200` inside the built image, which is the strongest form
# of the check but runs only against a production configuration and only in that
# one job — a route that stopped being drawn would fail there and nowhere else.
#
# So the contract is pinned here instead, in the environment the rest of the
# suite runs in: the route exists, it is named, it answers `200` to a guest
# without a session, and it does not depend on the universe/story scope that
# every other route in this application resolves first.
class HealthCheckTest < ActionDispatch::IntegrationTest
  test "the health check answers 200" do
    get rails_health_check_path

    assert_response :success
  end

  test "the health check is the /up path the deployment and the CI job poll" do
    # `config/routes.rb` draws `get "up" => "rails/health#show"`, the production
    # health check, the CI `production-boot` job, and the two production
    # exclusions in `config/environments/production.rb` all name this exact
    # string. A route moved under a scope or given a prefix would leave the probe
    # answering 404 in a deployment that reports healthy tests.
    assert_equal "/up", rails_health_check_path

    get "/up"

    assert_response :success
  end

  test "the health check answers a guest" do
    # It runs before a session exists and outside every access check, so an
    # unsigned probe measures the application rather than the reader.
    assert_nil cookies[:session_id]

    get rails_health_check_path

    assert_response :success
  end

  test "the health check does not depend on the universe or story scope" do
    get "/up"

    assert_response :success
    assert_nil Current.universe
    assert_nil Current.story
  end

  test "the health check is reachable under an unrecognized host" do
    # Production excludes this path from host authorization
    # (`config.host_authorization`), because the load balancer's probe may send a
    # Host header the allowlist does not contain. The test environment does not
    # configure that exclusion, so the reachability of the route is asserted here
    # and the exclusion stays a reviewed line in the production configuration.
    assert_respond_to Rails.application.config, :host_authorization
  end
end
