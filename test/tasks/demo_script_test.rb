require "test_helper"
require "digest"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

# Guards `script/demo`, the wrapper that runs the `db:demo:*` tasks with the password from
# `.env`.
#
# The gap it exists to close is real and silent: `Development::LocalPassword` falls back to a
# generated value when `UNIVERSE_MAKER_DEV_PASSWORD` is absent from the environment, and the
# application has no `.env` loader, so an exported-in-your-shell variable is invisible to a plain
# `bin/rails db:demo:reset`. The result was that every reset produced a different development
# password than the one the developer had configured.
#
# The property that matters most is that the value is not disclosed. It is read from an ignored
# file, exported into a child process, and never echoed -- so these tests copy the script into a
# scratch directory with a stubbed `bin/rails` that reports what it received, and assert against
# the real `.env` never being read.
class DemoScriptTest < ActiveSupport::TestCase
  SCRIPT_PATH = Rails.root.join("script/demo")
  PASSWORD_KEY = Development::LocalPassword::ENV_KEY
  SECRET = "correct-horse-battery-staple"

  # A value chosen to break naive handling: a space, a `$` that a shell would expand, and shell
  # metacharacters. Reading it must not evaluate any of them.
  AWKWARD_SECRET = "pa$$ word;'\"&|<>"

  setup do
    skip "script/demo is missing" unless SCRIPT_PATH.exist?
  end

  test "the script is executable and has a shell shebang" do
    assert File.executable?(SCRIPT_PATH), "script/demo must be executable"

    assert_match(/\A#!\/usr\/bin\/env bash\n/, SCRIPT_PATH.read,
      "script/demo must run under bash.")
  end

  test "the script exports the configured password to the task without printing it" do
    in_scratch_app do |dir, reporter|
      write_env(dir, "#{PASSWORD_KEY}=#{SECRET}\n")

      output, status = run_demo(dir, "check", "dark")

      assert status.success?, "script/demo check failed:\n#{output}"
      assert_secret_matches SECRET, reporter.exported_password,
        "script/demo must pass the .env value to the task through the environment."
      assert_no_secret_in output, SECRET
    end
  end

  # The value is quoted on the way out of the file and passed as a variable reference, so a space
  # or a metacharacter survives instead of being split or executed.
  test "a password containing shell metacharacters is passed through intact" do
    in_scratch_app do |dir, reporter|
      write_env(dir, "#{PASSWORD_KEY}=#{AWKWARD_SECRET}\n")

      output, status = run_demo(dir, "check", "dark")

      assert status.success?, "script/demo check failed:\n#{output}"
      assert_secret_matches AWKWARD_SECRET, reporter.exported_password
      assert_no_secret_in output, AWKWARD_SECRET
    end
  end

  test "a quoted password is unquoted once" do
    in_scratch_app do |dir, reporter|
      write_env(dir, %(#{PASSWORD_KEY}="#{SECRET}"\n))

      output, status = run_demo(dir, "check", "dark")

      assert status.success?, "script/demo check failed:\n#{output}"
      assert_secret_matches SECRET, reporter.exported_password
    end
  end

  test "a commented-out line is not read as a password" do
    in_scratch_app do |dir, reporter|
      write_env(dir, "# #{PASSWORD_KEY}=#{SECRET}\n")

      _, status = run_demo(dir, "check", "dark")

      assert status.success?, "script/demo check failed"
      assert_nil reporter.exported_password,
        "a commented line must not supply the password."
    end
  end

  # Absent or blank is the fallback the script exists to make visible: the loader would generate a
  # password for that load and print it, which is exactly the surprise this avoids.
  test "a missing password value warns instead of silently generating one" do
    in_scratch_app do |dir, reporter|
      write_env(dir, "SOMETHING_ELSE=value\n")

      output, status = run_demo(dir, "check", "dark")

      assert status.success?, "script/demo check failed:\n#{output}"
      assert_includes output, PASSWORD_KEY,
        "script/demo must name the variable when .env has no value for it."
      assert_nil reporter.exported_password
    end
  end

  test "reset requires an explicit universe" do
    in_scratch_app do |dir, _reporter|
      write_env(dir, "#{PASSWORD_KEY}=#{SECRET}\n")

      _, status = run_demo(dir, "reset")

      assert_not status.success?, "script/demo reset with no universe must fail"
    end
  end

  test "an unknown subcommand fails" do
    in_scratch_app do |dir, _reporter|
      write_env(dir, "#{PASSWORD_KEY}=#{SECRET}\n")

      output, status = run_demo(dir, "destroy", "dark")

      assert_not status.success?, "an unknown subcommand must fail"
      assert_includes output, "unknown command"
    end
  end

  test "a universe slug that is not a slug is refused before anything runs" do
    in_scratch_app do |dir, reporter|
      write_env(dir, "#{PASSWORD_KEY}=#{SECRET}\n")

      output, status = run_demo(dir, "check", "../../etc")

      assert_not status.success?, "a path-like argument must be refused"
      assert_includes output, "not a valid universe slug"
      assert_equal [], reporter.calls,
        "no task may run for a refused argument."
    end
  end

  # `reset` drops the database, so only the first universe can be the one it loads. The documented
  # workflow resets one and create-only loads the other, and the script has to reproduce it rather
  # than run two resets.
  test "extra universes after a reset are loaded, not reset again" do
    in_scratch_app do |dir, reporter|
      write_env(dir, "#{PASSWORD_KEY}=#{SECRET}\n")

      output, status = run_demo(dir, "reset", "dark", "lotr")

      assert status.success?, "script/demo reset failed:\n#{output}"
      assert_equal [ "db:demo:reset", "db:demo:load" ], reporter.calls.map { |call| call["task"] },
        "only the first universe may be reset; the rest are create-only loads."
      assert_equal %w[dark lotr], reporter.calls.map { |call| call["universe"] }
    end
  end

  # The reset task's own guard is what actually protects the database; the script sets
  # CONFIRM_DB_RESET for convenience, so assert it is passed rather than assumed.
  test "reset passes the confirmation the task requires" do
    in_scratch_app do |dir, reporter|
      write_env(dir, "#{PASSWORD_KEY}=#{SECRET}\n")

      _, status = run_demo(dir, "reset", "dark")

      assert status.success?
      assert_equal "1", reporter.calls.first["confirm"],
        "db:demo:reset aborts without CONFIRM_DB_RESET=1; the script must supply it."
    end
  end

  test "the script never prints the password variable's value from its own source" do
    source = SCRIPT_PATH.read

    # A `set -x` would echo every expanded assignment, including the password. Nothing in the
    # script may enable shell tracing.
    assert_no_match(/^\s*set\s+-[a-z]*x/m, source,
      "script/demo must not enable shell tracing; it would print the password.")

    # The value is exported by name from a variable, never interpolated into a command line where
    # it would show up in the process list.
    assert_no_match(/bin\/rails[^
]*\#\{PASSWORD_KEY\}/, source,
      "the password must not be interpolated into the bin/rails invocation.")
  end

  test "the script does not source the env file" do
    assert_no_match(/^\s*(source|\.)\s+[^ ]*ENV_FILE/m, SCRIPT_PATH.read,
      "script/demo must read .env without sourcing it; a dotenv file is not a program.")
  end

  test "a trailing comment in the env file is not treated as part of the value" do
    in_scratch_app do |dir, reporter|
      write_env(dir, "#{PASSWORD_KEY}=#{SECRET}\nOTHER=1\n")

      _, status = run_demo(dir, "check", "dark")

      assert status.success?
      assert_secret_matches SECRET, reporter.exported_password
    end
  end

  test "an env value with no trailing newline is still read" do
    in_scratch_app do |dir, reporter|
      write_env(dir, "FIRST=1\n#{PASSWORD_KEY}=#{SECRET}")

      _, status = run_demo(dir, "check", "dark")

      assert status.success?
      assert_secret_matches SECRET, reporter.exported_password
    end
  end

  private

  # Compares by digest so a failure prints `false`, never the value. An `assert_equal` on the
  # secret itself would write the development password into the test log on failure, which is the
  # exact leak the script is written to prevent.
  def assert_secret_matches(expected, actual, message = nil)
    assert_equal Digest::SHA256.hexdigest(expected.to_s),
      Digest::SHA256.hexdigest(actual.to_s),
      [ message, "the value the script exported did not match the one in .env (compared by digest)." ].compact.join(" ")
  end

  def assert_no_secret_in(output, secret)
    refute_includes output, secret,
      "script/demo printed the development password. It must stay out of every terminal and log."
  end

  def write_env(dir, contents)
    File.write(File.join(dir, ".env"), contents)
    File.chmod(0o600, File.join(dir, ".env"))
  end

  # Copies the script into a scratch directory shaped like the repository and drops in a
  # `bin/rails` stub that reports what it was given. Running the real tasks here would reset the
  # developer's database, so the stub is what makes these tests safe.
  def in_scratch_app
    Dir.mktmpdir("demo-script-test") do |dir|
      FileUtils.mkdir_p(File.join(dir, "script"))
      FileUtils.cp(SCRIPT_PATH, File.join(dir, "script/demo"))
      FileUtils.mkdir_p(File.join(dir, "bin"))

      report = File.join(dir, "calls.json")
      File.write(File.join(dir, "bin/rails"), stub_rails(report))
      FileUtils.chmod(0o755, File.join(dir, "bin/rails"))

      yield dir, Reporter.new(report)
    end
  end

  def run_demo(dir, *arguments)
    Open3.capture2e({ "UNIVERSE" => nil, "CONFIRM_DB_RESET" => nil, PASSWORD_KEY => nil },
      "bash", File.join(dir, "script/demo"), *arguments, chdir: dir)
  end

  def stub_rails(report)
    <<~RUBY
      #!/usr/bin/env ruby
      require "json"

      calls = File.exist?(#{report.inspect}) ? JSON.parse(File.read(#{report.inspect})) : []
      calls << {
        "task" => ARGV.first,
        "universe" => ENV["UNIVERSE"],
        "confirm" => ENV["CONFIRM_DB_RESET"],
        "password" => ENV[#{PASSWORD_KEY.inspect}],
        "argv" => ARGV
      }
      File.write(#{report.inspect}, JSON.generate(calls))
    RUBY
  end

  # Reads what the stub recorded. The password is only ever compared, never put in a message that
  # a failure would print, so a failing assertion cannot leak the value either.
  class Reporter
    def initialize(path)
      @path = path
    end

    def calls
      return [] unless File.exist?(@path)

      JSON.parse(File.read(@path))
    end

    def exported_password
      calls.first&.fetch("password", nil)
    end
  end
end
