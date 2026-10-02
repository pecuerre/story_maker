require "securerandom"
require "shellwords"

module Development
  # The password every User created by the development data loader gets.
  #
  # A checked-in development manifest used to carry the literal password, which
  # made a credential-shaped string part of the repository and easy to reuse
  # somewhere that mattered. The manifests now name only the account; this class
  # supplies the password at load time from one of two sources:
  #
  #   * `UNIVERSE_MAKER_DEV_PASSWORD` when the developer has exported it, so the
  #     login is one they can type and the same across every universe they load;
  #   * otherwise a value generated for that load, which the loader reports once
  #     on the terminal.
  #
  # Both sources are local-only. Nothing here reaches production, a deploy
  # command, or `db/seeds/`: the class is used by `Development::UniverseDataLoader`,
  # which refuses to write outside development.
  class LocalPassword
    ENV_KEY = "UNIVERSE_MAKER_DEV_PASSWORD"
    GENERATED_BYTES = 16

    attr_reader :value

    # A configured value wins so a developer can choose a reproducible login; an
    # absent or blank one falls back to a generated value rather than to a
    # literal kept in tracked code for a scanner to find.
    def self.resolve(env: ENV, generator: SecureRandom.method(:hex))
      configured = env[ENV_KEY].to_s.strip
      return new(configured, generated: false) if configured.present?

      new(generator.call(GENERATED_BYTES), generated: true)
    end

    def initialize(value, generated:)
      @value = value
      @generated = generated
    end

    def generated?
      @generated
    end

    # The line that makes this value available to the rest of a shell, quoted so
    # a configured value containing spaces still works. This is the only place
    # the value is written outside the database's password digest.
    def export_command
      "export #{ENV_KEY}=#{Shellwords.escape(value)}"
    end
  end
end
