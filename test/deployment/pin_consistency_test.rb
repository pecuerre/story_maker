require "test_helper"
require "json"

# Keeps the toolchain pins in one repository from disagreeing with each other.
#
# Ruby is named in `mise.toml` and in the Dockerfile's `FROM` line; Bun is named there and in
# `package.json`'s `packageManager` and in the `bun-version` every CI job installs. None of those
# derives from another. That is survivable while they agree and silently expensive when they do not: a
# Dockerfile that pins a different Ruby than the developer runs produces a "works on my machine"
# bundle, and a CI job that audits a lockfile with a different Bun than the one that wrote it audits
# something nobody else sees.
#
# The Dockerfile's base image is pinned by digest and every action in the workflow by commit SHA,
# both of which are easy to "tidy up" back into a mutable tag in a commit whose message says nothing
# about it. These cases assert the shape of a pin as well as its agreement, so the protection cannot
# be lost without a test failing.
class PinConsistencyTest < ActiveSupport::TestCase
  DOCKERFILE_PATH = Rails.root.join("Dockerfile")
  MISE_PATH = Rails.root.join("mise.toml")
  PACKAGE_JSON_PATH = Rails.root.join("package.json")
  WORKFLOW_PATH = Rails.root.join(".github/workflows/ci.yml")
  DEV_PATH = Rails.root.join("bin/dev")
  BASE_IMAGE_LINE = /^FROM docker\.io\/library\/ruby:(\S+?)@sha256:([0-9a-f]{64})\b/

  test "the Docker base image is the pinned Ruby version mise installs" do
    match = dockerfile.match(BASE_IMAGE_LINE)

    assert match, "the first FROM line must be docker.io/library/ruby:<version>-slim@sha256:<digest>. " \
      "A tag can be re-pointed by its publisher, so the tag alone is not a pin."
    assert_equal "#{mise_ruby}-slim", match[1],
      "The base image must be the Ruby version in mise.toml. A Ruby bump moves this version and the " \
      "digest together; see the comment above the FROM line, and Dependabot's docker ecosystem."
  end

  test "every FROM line naming the Ruby image carries a digest" do
    lines = dockerfile.lines.grep(/^FROM .*ruby:/)

    assert lines.any?, "the Dockerfile is expected to have a FROM line naming the Ruby base image"

    lines.each do |line|
      assert_match(/@sha256:[0-9a-f]{64}\b/, line,
        "#{line.strip} is not pinned by digest. A tag can be re-pointed by its publisher, so the tag " \
        "alone is not a pin.")
    end
  end

  test "every Bun version in the repository is the one mise installs" do
    bun = mise_bun
    dockerfile_version = dockerfile[/^ARG BUN_VERSION=(\S+)$/, 1]

    assert_equal bun, dockerfile_version,
      "The Dockerfile's BUN_VERSION must be the Bun version in mise.toml."
    assert_equal "bun@#{bun}", package_json.fetch("packageManager"),
      "package.json's packageManager must be the Bun version in mise.toml."
    assert_equal [ bun ], workflow_bun_versions.uniq,
      "Every CI job installs one Bun version, and it must be the one in mise.toml."
  end

  test "every GitHub Action is pinned to a commit SHA with its release tag" do
    uses = File.readlines(WORKFLOW_PATH).grep(/^\s*uses:/)

    assert uses.any?, "the workflow is expected to use actions"

    uses.each do |line|
      reference = line.split("uses:", 2).last.strip

      assert_match(/^[\w.-]+\/[\w.-]+@[0-9a-f]{40} # v[\w.-]+$/, reference,
        "#{reference.inspect} is not pinned to a commit SHA with its release tag in a comment. A " \
        "mutable tag can change what a job runs without a commit here.")
    end
  end

  # The finding this guards was `gem install foreman` inside `bin/dev`: every developer's dev server
  # ran whatever foreman had published most recently, and a release could change the behaviour of a
  # script that is supposed to be a fixed entry point.
  test "bin/dev does not install a gem at runtime" do
    code = DEV_PATH.readlines.reject { |line| line.strip.start_with?("#") }.join

    assert_no_match(/gem install/, code,
      "bin/dev must not install gems. foreman is a bundled development dependency; see the Gemfile.")
    assert_match(/bundle exec foreman start -f Procfile\.dev/, code)
  end

  private
    def dockerfile = DOCKERFILE_PATH.read

    def mise = MISE_PATH.read

    # mise.toml is two string assignments. A regex is deliberate: this reads the pin the way a human
    # does, and adding a tool to mise.toml cannot make it wrong.
    def mise_ruby = mise[/^ruby\s*=\s*"([^"]+)"/, 1].presence || flunk("mise.toml declares no ruby version")

    def mise_bun = mise[/^bun\s*=\s*"([^"]+)"/, 1].presence || flunk("mise.toml declares no bun version")

    def package_json = JSON.parse(PACKAGE_JSON_PATH.read)

    def workflow_bun_versions
      File.read(WORKFLOW_PATH).scan(/bun-version:\s*"?([\d.]+)"?/).flatten
    end
end
