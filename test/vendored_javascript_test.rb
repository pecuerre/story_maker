require "test_helper"
require "importmap/npm"
require "json"

# Guards the provenance of the JavaScript copied into `vendor/javascript/`.
#
# `./bin/importmap pin --download` fetches a file and commits it, so nothing in the tree compares
# those bytes to the release they claim to be, and Importmap Audit reads a version out of the pin
# comment rather than out of the file it audits. A hand-edited or half-written vendored copy would
# therefore pass every existing check and be served to every browser.
#
# Bun verifies the sha512 of every tarball it installs against `bun.lock`, so the file inside
# `node_modules` is known to be the locked release. Comparing the vendored copy with it is a real
# provenance answer and needs no network call, which is why `config/vendored_javascript.yml` records
# where each asset lives inside its package.
class VendoredJavascriptTest < ActiveSupport::TestCase
  VENDOR_ROOT = Rails.root.join("vendor/javascript")
  MANIFEST_PATH = Rails.root.join("config/vendored_javascript.yml")
  LOCKFILE_PATH = Rails.root.join("bun.lock")
  PACKAGE_JSON_PATH = Rails.root.join("package.json")
  INTEGRITY_PREFIX = "sha512-"

  test "every vendored JavaScript file is declared in the manifest" do
    declared = manifest.values.map { |entry| entry.fetch("file") }.sort

    assert_equal declared, vendored_files,
      "vendor/javascript holds a file that config/vendored_javascript.yml does not describe. " \
      "Declare it there so its provenance is checked, or remove the copy."
  end

  test "each vendored asset is a direct dependency of this package" do
    manifest.each do |name, entry|
      package = entry.fetch("package")

      assert_includes declared_dependencies.keys, package,
        "#{name} is vendored from #{package}, which package.json does not depend on directly. " \
        "A vendored importmap asset has to come from a tracked package."
    end
  end

  test "the pinned, locked, and declared range agree on one version" do
    pinned = pinned_versions
    locked = locked_versions
    declared = declared_dependencies

    manifest.each do |name, entry|
      package = entry.fetch("package")
      resolved = locked[package]
      range = declared[package]

      assert resolved.present?, "bun.lock resolves no version for #{package}, so #{name} has no locked release to compare against."
      assert range.present?, "package.json declares no range for #{package}, so #{name} cannot be version-checked against it."

      assert_equal resolved, pinned[package],
        "The `# @version` comment on the #{package} importmap pin says #{pinned[package].inspect} " \
        "while bun.lock resolves #{resolved}. Importmap Audit reads the comment, so the two must agree."

      assert range_satisfied?(range, Gem::Version.new(resolved)),
        "bun.lock resolves #{package} #{resolved}, which does not satisfy the range " \
        "\"#{range}\" package.json declares. Refresh the lockfile so the vendored copy, the pin " \
        "comment, and the declared range are one version."
    end
  end

  test "bun.lock pins an integrity for every vendored package" do
    manifest.each do |name, entry|
      package = entry.fetch("package")
      integrity = lockfile_integrity(package)

      assert integrity.present?, "bun.lock records no #{INTEGRITY_PREFIX} integrity for #{package}."

      assert integrity.start_with?(INTEGRITY_PREFIX),
        "bun.lock records \"#{integrity}\" for #{package}; only an #{INTEGRITY_PREFIX} tarball " \
        "digest makes the installed copy verifiable, and that digest is what #{name} is checked against."
    end
  end

  test "the vendored bytes are the locked release" do
    manifest.each do |name, entry|
      vendored = VENDOR_ROOT.join(entry.fetch("file"))
      installed = Rails.root.join("node_modules", entry.fetch("package"), entry.fetch("package_path"))

      assert vendored.exist?, "vendor/javascript/#{entry.fetch("file")} does not exist, but the manifest describes it."
      assert vendored.size.positive?, "vendor/javascript/#{entry.fetch("file")} is empty."

      # The suite runs in CI only after `bun install --frozen-lockfile`, so a missing file there is
      # a broken job rather than an un-installed workstation. Skipping is only for local runs.
      if !installed.exist? && ENV["CI"].present?
        flunk "#{installed.relative_path_from(Rails.root)} does not exist. CI installs the JavaScript " \
          "dependencies before this suite runs, so this job cannot check #{name}'s provenance."
      end
      skip "JavaScript dependencies are not installed; run `bun install --frozen-lockfile` to check vendored provenance" unless installed.exist?

      assert_equal digest(installed), digest(vendored),
        "vendor/javascript/#{entry.fetch("file")} is not the #{entry.fetch("package")} release " \
        "bun.lock locks. Refresh it with `./bin/importmap pin --download " \
        "#{entry.fetch("package")}@#{locked_versions.fetch(entry.fetch("package"))}`, or find out " \
        "what changed the committed copy."
    end
  end

  private
    def manifest
      @manifest ||= YAML.safe_load_file(MANIFEST_PATH).to_h
    end

    def vendored_files
      Dir.children(VENDOR_ROOT).select { |name| name.end_with?(".js") }.sort
    end

    # Read the versions the way Importmap Audit does, so a drift between this check and the audit
    # is impossible rather than merely unlikely.
    def pinned_versions
      npm = Importmap::Npm.new(MANIFEST_PATH.dirname.join("importmap.rb").to_s,
        vendor_path: VENDOR_ROOT.to_s)

      pairs = nil
      capture_io { pairs = npm.packages_with_versions }

      pairs.to_h
    end

    def lockfile
      @lockfile ||= JSON.parse(LOCKFILE_PATH.read.gsub(/,(\s*[}\]])/) { $1 })
    end

    def locked_packages
      lockfile.fetch("packages")
    end

    def locked_versions
      locked_packages.transform_values { |specifier| specifier.first.split("@").last }
    end

    # Each lockfile entry is `[ "package@version", registry, metadata, integrity ]`.
    def lockfile_integrity(package)
      Array(locked_packages[package])[3]
    end

    def declared_dependencies
      manifest_json = JSON.parse(PACKAGE_JSON_PATH.read)

      manifest_json.fetch("dependencies", {}).merge(manifest_json.fetch("devDependencies", {}))
    end

    # Every range `package.json` declares is a caret range, so this is the only npm range syntax
    # needed here. Anything else raises instead of guessing: a `~`, a `>=`, or a workspace protocol
    # would otherwise be silently accepted as "satisfied" by a check that never ran.
    def range_satisfied?(range, version)
      raise ArgumentError, "#{range.inspect} is not a caret range; extend this check" unless range.start_with?("^")

      floor = Gem::Version.new(range.delete_prefix("^"))
      segments = floor.segments
      first_significant = segments.index { |segment| segment.positive? } || segments.length - 1
      ceiling = segments.first(first_significant).map { 0 } + [ segments[first_significant] + 1 ] + Array.new(segments.length - first_significant - 1, 0)

      version >= floor && version < Gem::Version.new(ceiling.join("."))
    end

    def digest(path) = Digest::SHA256.file(path).hexdigest
end
