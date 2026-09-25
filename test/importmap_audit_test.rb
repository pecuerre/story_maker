require "test_helper"
require "importmap/npm"

class ImportmapAuditTest < ActiveSupport::TestCase
  test "includes the vendored Tom Select version in the audit package list" do
    npm = Importmap::Npm.new(
      Rails.root.join("config/importmap.rb").to_s,
      vendor_path: Rails.root.join("vendor/javascript").to_s
    )

    packages = nil
    stdout, = capture_io { packages = npm.packages_with_versions }

    assert_includes packages, [ "tom-select", "2.6.2" ]
    assert_not_includes stdout, "Ignoring tom-select"
  end
end
