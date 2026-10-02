require "test_helper"

# The tag workspace's declarative configuration, characterized rather than
# exercised.
#
# `TagsHelper` derives a taxonomy's whole workspace block — its copy, its model
# parameter, its URLs, and the name of the editor's field builder — from the type
# name, so adding a taxonomy is meant to be one entry in a metadata table plus its
# locale block rather than a second hand-maintained block. That is a good trade
# only while the derivation and the things it names stay in agreement, and every
# way they can disagree fails silently or late:
#
# - a type added to a type list with no metadata entry raises `KeyError` from
#   `UNIVERSE_TAG_METADATA.fetch` while a page is rendering;
# - a metadata block that quietly drops one of its five copy keys still renders,
#   because `translated_metadata` merges only the keys a block happens to
#   contain, and the tree partial then reads `nil` where it expected a sentence;
# - a copy key with no translation renders the key itself to one locale only;
# - a field-builder helper that is not defined, or a route that is not named after
#   the type, is a `NoMethodError`/`UrlGenerationError` at render time.
#
# The taxonomy tree's own URL surface is asserted in
# `test/controllers/modal_json_contract_test.rb`, and its editor descriptors in
# `test/helpers/modal_fields_helper_test.rb`; this file covers what only the
# helper can be asked about.
class TagsHelperTest < ActionView::TestCase
  include ApplicationHelper
  include ModalFields
  include TagsHelper

  # The five copy keys every taxonomy's block declares, plus the one extra only
  # the Scene taxonomy has. Listed explicitly rather than derived, because the
  # point of the test is to fail when a block's key set changes.
  SHARED_COPY_KEYS = %i[
    title_key description_key empty_description_key read_only_empty_description_key new_label_key
  ].freeze

  STORY_COPY_KEYS = { "scene" => %i[confirm_message_key] }.freeze

  test "the two scope lists and the two metadata tables describe the same taxonomies" do
    # The one that fails newest and loudest. `universe_tag_workspace_config` and
    # `story_tag_workspace_config` both `fetch` their metadata, so a taxonomy in a
    # type list and not in its table is a `KeyError` rather than a missing field.
    assert_equal TagsHelper::UNIVERSE_TAG_TYPES, TagsHelper::UNIVERSE_TAG_METADATA.keys,
      "the universe type list and its metadata table disagree"
    assert_equal TagsHelper::STORY_TAG_TYPES, TagsHelper::STORY_TAG_METADATA.keys,
      "the story type list and its metadata table disagree"
  end

  test "a taxonomy belongs to exactly one scope" do
    # The two lists become two different URL families and two different records'
    # details pages, so a type in both would render the universe taxonomy's editor
    # inside the story workspace.
    assert_empty TagsHelper::UNIVERSE_TAG_TYPES & TagsHelper::STORY_TAG_TYPES
  end

  test "every taxonomy's block declares the same five copy keys" do
    metadata_by_type.each do |type, metadata|
      expected = (SHARED_COPY_KEYS + STORY_COPY_KEYS.fetch(type, [])).sort

      assert_equal expected, metadata.keys.sort,
        "#{type}'s block declares #{metadata.keys.sort.inspect} rather than #{expected.inspect}"
    end
  end

  test "every copy key a block declares resolves in both locales" do
    # `translations_test` proves the two locale files carry the same key set, so
    # this is what catches a block naming a key that is in neither.
    metadata_by_type.each do |type, metadata|
      metadata.each do |name, key|
        [ :en, :es ].each do |locale|
          assert I18n.exists?(key, locale),
            "#{type}'s #{name} names #{key.inspect}, which has no #{locale} translation"
        end
      end
    end
  end

  test "every taxonomy's copy sits in that taxonomy's own locale block" do
    # The keys are built as `tags.types.<type>.<name>`, so a block that pointed at
    # another taxonomy's copy would translate cleanly and say the wrong thing.
    metadata_by_type.each do |type, metadata|
      metadata.each do |name, key|
        assert key.start_with?("tags.types.#{type}."), "#{type}'s #{name} names #{key.inspect}"
      end
    end
  end

  test "every declared taxonomy has the editor helper its workspace reaches for by name" do
    # `tag_workspace_base` calls `public_send(:"#{type}_tag_taxonomy_fields")`,
    # because the metadata stores a method's *name* rather than a lambda: a
    # constant cannot capture the view, which is what owns the route helpers.
    taxonomy_types.each do |type|
      assert_respond_to self, :"#{type}_tag_taxonomy_fields",
        "#{type} has no editor helper for `tag_workspace_base` to call"
    end
  end

  test "every declared taxonomy's editor helper takes the one per-call node list" do
    # The parent selector is built from that list, which is the only value a
    # taxonomy does not hold in its metadata. The argument is optional because a
    # taxonomy with no tags yet still renders its editor, with a blank option and
    # nothing else.
    taxonomy_types.each do |type|
      assert_equal [ [ :opt, :nodes ] ], method(:"#{type}_tag_taxonomy_fields").parameters,
        "#{type}'s editor helper does not take the one optional ordered node list"
    end
  end

  test "the routes each taxonomy's URLs are derived from exist under the derived names" do
    # `universe_tag_workspace_config` and `story_tag_workspace_config` build all
    # four URLs by interpolating the type name. A renamed route therefore reads as
    # a URL that cannot be generated, on a taxonomy page, for every row.
    routes = Rails.application.routes.url_helpers

    TagsHelper::UNIVERSE_TAG_TYPES.each do |type|
      assert_respond_to routes, :"universe_#{type}_tags_path"
      assert_respond_to routes, :"universe_#{type}_tag_path"
    end

    TagsHelper::STORY_TAG_TYPES.each do |type|
      assert_respond_to routes, :"universe_story_#{type}_tags_path"
      assert_respond_to routes, :"universe_story_#{type}_tag_path"
    end
  end

  test "the scene taxonomy is the only one that declares a delete confirmation" do
    # A confirmation is a lambda the tree calls per node, so it is interpolated at
    # call time rather than resolved once. Any other taxonomy needing one has to
    # say so here too.
    with_confirmation = metadata_by_type.select { |_type, metadata| metadata.key?(:confirm_message_key) }

    assert_equal STORY_COPY_KEYS.keys, with_confirmation.keys
  end

  private
    def taxonomy_types
      TagsHelper::UNIVERSE_TAG_TYPES + TagsHelper::STORY_TAG_TYPES
    end

    def metadata_by_type
      TagsHelper::UNIVERSE_TAG_METADATA.merge(TagsHelper::STORY_TAG_METADATA)
    end
end
