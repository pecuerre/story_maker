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
          Kamal::Configuration.create_from(config_file: path)
        end
      end

      assert_match(/bogus/, error.message)
    end
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

    def kamal_config
      Kamal::Configuration.create_from(config_file: CONFIG_PATH)
    end

    # `create_from` writes ENV["KAMAL_DESTINATION"], which would otherwise leak into later tests.
    def with_destination
      previous = ENV["KAMAL_DESTINATION"]
      yield
    ensure
      ENV["KAMAL_DESTINATION"] = previous
    end
end
