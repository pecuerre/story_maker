require "test_helper"
require "yaml"

class DevelopmentComposeTest < ActiveSupport::TestCase
  COMPOSE_PATH = Rails.root.join("compose.yaml")
  DOCKERFILE_PATH = Rails.root.join("Dockerfile.dev")
  ENTRYPOINT_PATH = Rails.root.join("bin/docker-dev-entrypoint")

  test "Compose builds the development image, persists isolated storage, publishes port and checks /up" do
    compose = YAML.safe_load(COMPOSE_PATH.read)
    service = compose.fetch("services").fetch("web")

    assert_equal "Dockerfile.dev", service.dig("build", "dockerfile")
    assert_equal [ "127.0.0.1:3000:3000" ], service.fetch("ports")
    # The story-interchange source is host configuration mounted read-only at the
    # path STORY_INTERCHANGE_IMPORT_ROOT names; the page still lists only folders
    # under that root.
    assert_equal [
      "./app:/rails/app",
      "./lib:/rails/lib",
      "${STORY_INTERCHANGE_SOURCE_DIR:-../tcs.git}:/sources/tcs.git:ro",
      "storage:/rails/storage"
    ], service.fetch("volumes")
    assert_equal "development", service.dig("environment", "RAILS_ENV")
    assert_includes service.dig("healthcheck", "test").join(" "), "http://127.0.0.1:3000/up"
    assert_equal({ "storage" => nil }, compose.fetch("volumes"))
    assert service.fetch("volumes").none? { |mount| mount.start_with?("./storage") },
      "development data must stay in a Compose-managed volume, not the host storage path"
  end

  test "development image pins the same Ruby and Bun versions as the host toolchain" do
    ruby = Rails.root.join("mise.toml").read[/^ruby\s*=\s*"([^"]+)"/, 1]
    bun = Rails.root.join("mise.toml").read[/^bun\s*=\s*"([^"]+)"/, 1]

    base_image_line = DOCKERFILE_PATH.read.lines.find { |line| line.start_with?("FROM ") }

    assert_match(/^FROM docker\.io\/library\/ruby:#{Regexp.escape(ruby)}-slim@sha256:[0-9a-f]{64}$/,
      base_image_line.strip)
    assert_equal bun, DOCKERFILE_PATH.read[/^ARG BUN_VERSION=(\S+)$/, 1]
    assert_includes DOCKERFILE_PATH.read, "libclang-dev",
      "the locked Selma gem builds through bindgen and needs libclang in the development image"
    assert_includes DOCKERFILE_PATH.read, "bun install --frozen-lockfile"
    assert_includes DOCKERFILE_PATH.read, "bun run build:css"
  end

  test "development entrypoint prepares schema, loads demo data only when empty, and starts a reachable server" do
    entrypoint = ENTRYPOINT_PATH.read

    assert_includes entrypoint, "bin/rails db:prepare"
    assert_includes entrypoint, "UNIVERSE=dark bin/rails db:demo:load"
    assert_includes entrypoint, "exec bundle exec foreman start -f Procfile.container-dev"
    assert_includes entrypoint, "storage/.development-password"
    assert_includes entrypoint, "umask 077"
    assert_includes entrypoint, "chmod 600 \"$password_file\""
    assert_includes entrypoint, "export UNIVERSE_MAKER_DEV_PASSWORD=\"$dev_password\""
    assert_includes entrypoint, "Password (local only; saved in this Compose volume)"
    assert_match(/case\s+"\$universe_state".*?present\).*?missing\)/m, entrypoint)
    refute_includes entrypoint, "db:demo:reset"
    refute_includes entrypoint, "bin/docker-entrypoint"
  end

  test "container development runs Rails reload and the existing CSS watcher" do
    procfile = Rails.root.join("Procfile.container-dev").read

    assert_includes procfile, "bin/rails server -b 0.0.0.0 -p 3000"
    assert_includes procfile, "bun run watch:css"
    assert_includes Rails.root.join("config/environments/development.rb").read,
      "config.enable_reloading = true"
  end
end
