require "test_helper"

# The word a result row's badge wears, and the eight taxonomies that share the
# `tag` kind.
#
# The label is resolved per request rather than held in the map, because this
# file is loaded once and a label resolved here would be the language of
# whichever request loaded it first. The two maps exist instead of composing a
# taxonomy's name onto a lowercased kind, because a locale decides its own word
# order: "Character tag" and "Etiqueta de personaje" are not the same sentence.
class Search::KindsTest < ActiveSupport::TestCase
  test "a kind is named by its own word in both locales" do
    assert_equal "Character", Search::Kinds.label_for("character")
    assert_equal "Scene element", Search::Kinds.label_for("scene_element")
    assert_equal "Tag", Search::Kinds.label_for("tag")

    I18n.with_locale(:es) do
      assert_equal "Personaje", Search::Kinds.label_for("character")
      assert_equal "Elemento de escena", Search::Kinds.label_for("scene_element")
      assert_equal "Etiqueta", Search::Kinds.label_for("tag")
    end
  end

  test "a taxonomy is named as a whole phrase, not composed from the kind" do
    assert_equal "Character tag", Search::Kinds.label_for("tag", "Character")
    assert_equal "Scene tag", Search::Kinds.label_for("tag", "Scene")

    # The Spanish entry is not "Personaje etiqueta" with the noun moved: the
    # sentence is the taxonomy's own, and a lowercased kind spliced onto it is
    # the word order English happens to use.
    I18n.with_locale(:es) do
      assert_equal "Etiqueta de personaje", Search::Kinds.label_for("tag", "Character")
      assert_equal "Etiqueta de escena", Search::Kinds.label_for("tag", "Scene")
    end
  end

  test "a kind this version does not know answers with its own value" do
    # A value the code cannot name is not copy it can invent, and a missing
    # translation raises in the test environment.
    assert_equal "spaceship", Search::Kinds.label_for("spaceship")
    assert_equal "Tag", Search::Kinds.label_for("tag", "Spaceship")
  end

  test "every kind and taxonomy the registry indexes is named in both locales" do
    # The kinds are declared in the models and the labels live here, so nothing
    # connects the two lists at runtime. A model indexed under a new kind or a new
    # taxonomy without a label would raise on the first result row that carries
    # it, so the registry is walked rather than repeated.
    declarations = Search::Registry.models.map(&:search_declaration)
    kinds = declarations.filter_map(&:kind).uniq
    pairs = declarations.filter_map { |declaration|
      [ declaration.kind, declaration.taxonomy ] if declaration.taxonomy.present?
    }.uniq

    assert_not_empty kinds

    %i[en es].each do |locale|
      I18n.with_locale(locale) do
        kinds.each { |kind| assert_predicate Search::Kinds.label_for(kind), :present?, "#{locale}: #{kind}" }

        pairs.each do |kind, taxonomy|
          assert_predicate Search::Kinds.label_for(kind, taxonomy), :present?, "#{locale}: #{kind}/#{taxonomy}"
          assert_not_equal Search::Kinds.label_for(kind), Search::Kinds.label_for(kind, taxonomy),
            "#{locale}: #{kind}/#{taxonomy} falls back to the bare kind, so the taxonomy is not named"
        end
      end
    end
  end

  test "no taxonomy is named twice under the same kind" do
    keys = Search::Kinds::TAXONOMY_LABEL_KEYS.values

    assert_equal keys.size, keys.uniq.size, "two taxonomies resolve to one label key"
  end
end
