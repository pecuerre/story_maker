require "test_helper"

class TropeCatalogTest < ActiveSupport::TestCase
  test "the proof-of-concept catalogue has ten unique sourced entries" do
    entries = TropeCatalog.entries

    assert_equal 10, entries.size
    assert_equal entries.size, entries.map(&:slug).uniq.size
    assert entries.all? { |entry| entry.description_key.present? && entry.craft_note_key.present? }
    assert entries.all? { |entry| entry.source_url.start_with?("https://tvtropes.org/") }
  end

  test "lookup returns nil for a slug outside the curated catalogue" do
    assert_nil TropeCatalog.find("not-a-trope")
  end
end
