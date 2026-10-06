require "test_helper"
require "kamal"
require "tmpdir"

# Validates `config/deploy.yml` through Kamal's own loader instead of through YAML.
#
# `bin/kamal config` is the obvious way to check a deployment file, and the documentation forbids
# running it in CI because the resolved configuration includes secret values. That leaves the file
# unvalidated until someone deploys and Kamal rejects it, which is the worst possible moment to find
# out that a role lost its host. Loading it here runs exactly the validations `bin/kamal config`
# runs -- ERB rendering, YAML parsing, Kamal's schema validator -- and the test asserts on structure
# only. No value from the file, and no value from `.kamal/secrets`, is ever read into an assertion
# or printed.
class KamalConfigurationTest < ActiveSupport::TestCase
  CONFIG_PATH = Rails.root.join("config/deploy.yml")

  # `Kamal::Secrets` — reached from every `Kamal::Configuration.create_from` — does
  # `require "dotenv"`, and `dotenv` registers a Railtie that loads the repository's real `.env`
  # into the **test process**, once per worker, the first time a configuration is built here.
  # That is the developer's own `.env`, so `bin/rails test` was reading their
  # `UNIVERSE_MAKER_DEV_PASSWORD` and every other value they keep in it.
  #
  # It surfaced as a flake rather than as this: `UniverseDataLoaderTest` asserts that the loader
  # *generates* a password when the environment configures none, and it failed roughly one run in
  # three — on whichever run put that test in a worker that had already touched Kamal. Nothing
  # about the loader had changed; the answer depended on how the suite was distributed.
  #
  # It is undone inside the load rather than only in the teardown, because a test must not observe
  # the leak it caused: a teardown alone would leave whichever Kamal test ran first in a worker
  # asserting against a polluted environment, which is the flake again in a different place. The
  # teardown stays as a backstop for a call path added later without the wrapper.
  setup do
    @environment_before_kamal = ENV.to_hash
  end

  teardown do
    ENV.replace(@environment_before_kamal)
  end

  test "the deployment config loads and validates" do
    config = with_destination { kamal_config }

    assert_equal "universe_maker", config.service
  end

  test "the deployment config names a web role with a host" do
    config = with_destination { kamal_config }
    web = config.servers.roles.find { |role| role.name == "web" }

    assert web, "config/deploy.yml must deploy the web role; Kamal has nothing to deploy to without it."
    assert web.hosts.any?, "the web role must have at least one host."
  end

  test "the deployment config resolves a builder arch and a storage volume" do
    config = with_destination { kamal_config }

    assert config.builder.arches.any?, "config/deploy.yml must resolve at least one builder arch."
    assert_includes Array(config.raw_config.volumes), "universe_maker_storage:/rails/storage",
      "the SQLite databases and Active Storage files live in /rails/storage; without the volume a deploy starts from an empty data directory."
    assert_equal "/rails/public/assets", config.raw_config.asset_path
  end

  # Proof that the green tests above mean something: Kamal's loader does reject a bad file, so a
  # passing validation is a real result rather than a loader that accepts anything. An unknown key
  # is the realistic failure -- a mistyped `env:` block or a leftover key from another tool -- and it
  # is rejected on its own merits rather than by an unrelated missing field.
  test "an unknown key in the deployment config is rejected by the same loader" do
    with_config_file("bogus: true") do |path|
      error = with_destination do
        assert_raises Kamal::ConfigurationError do
          # Guarded like `kamal_config`: this is the call that reaches `Kamal::Secrets`, and so
          # the one that can pull a `.env` into this process.
          without_leaking_dotenv { Kamal::Configuration.create_from(config_file: path) }
        end
      end

      assert_match(/bogus/, error.message)
    end
  end

  # The loader this file uses has a side effect nothing in its API mentions — see `setup`. This is
  # the assertion that keeps it contained: a leak would otherwise be invisible here and surface as
  # a random failure somewhere else entirely.
  test "building a configuration does not leave the developer's .env in this process" do
    with_destination { kamal_config }

    assert_equal @environment_before_kamal, ENV.to_hash,
      "loading a Kamal configuration pulled a .env into the test process. Every later test that " \
      "reads ENV would then depend on which worker happened to touch Kamal first."
  end

  private
    # Writes a temporary config that is a minimal valid deployment plus `extra`, so the unknown key
    # is the only thing that can make Kamal reject it.
    def with_config_file(extra)
      Dir.mktmpdir do |directory|
        path = Pathname.new(directory).join("deploy.invalid.yml")
        path.write(<<~YAML)
          service: universe_maker
          image: universe_maker
          registry:
            server: localhost:5555
          #{extra}
        YAML

        yield path
      end
    end

    # Every call that reaches `Kamal::Secrets` goes through this, because that is the call that
    # can pull a `.env` into this process.
    def kamal_config
      without_leaking_dotenv { Kamal::Configuration.create_from(config_file: CONFIG_PATH) }
    end

    # Restores the whole environment rather than the one variable, because what the load writes is
    # whatever the developer's `.env` happens to hold and this file cannot know the names in
    # advance.
    def without_leaking_dotenv
      environment = ENV.to_hash
      yield
    ensure
      ENV.replace(environment)
    end

    # `create_from` writes ENV["KAMAL_DESTINATION"], which would otherwise leak into later tests.
    def with_destination
      previous = ENV["KAMAL_DESTINATION"]
      yield
    ensure
      ENV["KAMAL_DESTINATION"] = previous
    end
end
