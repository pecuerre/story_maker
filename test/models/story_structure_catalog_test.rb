require "test_helper"

class StoryStructureCatalogTest < ActiveSupport::TestCase
  test "the catalogue holds unique slugs with acts and beats" do
    entries = StoryStructureCatalog.entries

    assert_equal 2, entries.size
    assert_equal entries.size, entries.map(&:slug).uniq.size
    assert entries.all? { |entry| entry.acts.any? && entry.acts.all? { |act| act.beats.any? } }
  end

  test "lookup returns nil for a slug outside the curated catalogue" do
    assert_nil StoryStructureCatalog.find("not-a-structure")
  end

  test "every catalogue label and description resolves in every locale" do
    keys = StoryStructureCatalog.entries.flat_map do |entry|
      [ entry.name_key, entry.description_key ] + entry.acts.flat_map do |act|
        [ act.name_key ] + act.beats.flat_map { |beat| [ beat.name_key, beat.description_key ] }
      end
    end

    I18n.available_locales.each do |locale|
      keys.each do |key|
        assert I18n.t(key, locale: locale).present?, "#{key} is missing in #{locale}"
      end
    end
  end
end
