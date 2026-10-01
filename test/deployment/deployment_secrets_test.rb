require "test_helper"

# Guards the deployment secret contract. `.kamal/secrets` and `config/master.key` are both
# gitignored local files, so nothing in the repository proves they agree: a stale key in one of
# them is invisible until a deploy injects it and production fails to decrypt `credentials.yml.enc`
# at boot. That is a loud failure rather than a silent vulnerability, which is the good case -- the
# bad case is that nobody notices the drift for months. These tests run wherever the local files
# exist and skip elsewhere, so CI still covers only the tracked half of the contract.
class DeploymentSecretsTest < ActiveSupport::TestCase
  SECRETS_PATH = Rails.root.join(".kamal/secrets")
  MASTER_KEY_PATH = Rails.root.join("config/master.key")
  CREDENTIALS_PATH = Rails.root.join("config/credentials.yml.enc")
  # Rails derives its encryptor key from this and rejects any other length outright
  # (ActiveSupport::EncryptedFile::InvalidKeyLengthError).
  MASTER_KEY_LENGTH = 32

  test "the Kamal secret and the Rails master key are the same key" do
    skip "no local deployment secret file" unless SECRETS_PATH.exist?
    skip "no local master key" unless MASTER_KEY_PATH.exist?

    assert_equal master_key, kamal_secret,
      "config/master.key and the RAILS_MASTER_KEY in .kamal/secrets have drifted apart. Kamal " \
      "injects the secret, so a deploy would ship a key that cannot decrypt credentials.yml.enc " \
      "and the container would fail to boot. Copy the same value into both files."
  end

  test "both key files use the exact length Rails requires" do
    skip "no local deployment secret file" unless SECRETS_PATH.exist?
    skip "no local master key" unless MASTER_KEY_PATH.exist?

    assert_equal MASTER_KEY_LENGTH, master_key.length,
      "Rails requires a #{MASTER_KEY_LENGTH}-character master key and raises on any other length."
    assert_equal MASTER_KEY_LENGTH, kamal_secret.length,
      "Rails requires a #{MASTER_KEY_LENGTH}-character master key and raises on any other length."
  end

  test "the shipped credentials decrypt with the local master key" do
    skip "no local master key" unless MASTER_KEY_PATH.exist?
    skip "no encrypted credentials" unless CREDENTIALS_PATH.exist?

    secret_key_base = ActiveSupport::EncryptedConfiguration.new(
      config_path: CREDENTIALS_PATH,
      key_path: MASTER_KEY_PATH,
      env_key: "RAILS_MASTER_KEY",
      raise_if_missing_key: true
    ).config[:secret_key_base]

    assert secret_key_base.present?,
      "config/credentials.yml.enc no longer yields a secret_key_base under config/master.key."
  end

  test "the key files are not readable by group or others" do
    { SECRETS_PATH => "kamal secret", MASTER_KEY_PATH => "master key" }.each do |path, label|
      next unless path.exist?

      mode = format("%o", path.stat.mode & 0o777)

      assert_operator mode.to_i(8), :<=, 0o600,
        "config/#{label} is mode #{mode}; it must be 0600 or stricter."
    end
  end

  test "the deployment config ships the master key as a secret rather than cleartext" do
    config = YAML.safe_load_file(Rails.root.join("config/deploy.yml"), aliases: true)

    assert_includes Array(config.dig("env", "secret")), "RAILS_MASTER_KEY",
      "config/deploy.yml must pass RAILS_MASTER_KEY through env.secret."
    refute_includes Array(config.dig("env", "clear")), "RAILS_MASTER_KEY",
      "RAILS_MASTER_KEY must never appear in the env.clear list."
  end

  private
    def master_key = MASTER_KEY_PATH.read.strip

    def kamal_secret
      match = SECRETS_PATH.read[/^RAILS_MASTER_KEY=(.*)$/, 1]

      assert match.present?, "#{SECRETS_PATH} does not define RAILS_MASTER_KEY."
      match.strip
    end
end
