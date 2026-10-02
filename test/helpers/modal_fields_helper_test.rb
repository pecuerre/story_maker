require "test_helper"

# The serialized hand-off the modal editors are prefilled from. Two contracts are
# pinned here, because both were silent: a stored second was dropped on the way
# out (so opening an editor and saving rewrote the column to zero seconds), and
# Relation/Ownership shipped no `name` key at all while their models prefer one
# for `display_string` and the composite slug.
#
# The rest of this file characterizes the two **descriptor** contracts the
# taxonomy editor is built from, because both are silent in the same way. The
# descriptors are what `taxonomy_tree_controller.js` builds the whole editor
# from, so a descriptor is not a description of a form — it *is* the form's
# definition. A descriptor naming a field the tag model does not have raises
# inside `shared/_taxonomy_node`'s `node.public_send`, and a label that reaches
# the browser untranslated shows one language to every locale after the first.
#
# `test/controllers/modal_json_contract_test.rb` is the other half: it proves the
# flat-list editors' server-rendered forms and these serializers agree, which is
# the one statement neither file can make alone.
class ModalFieldsHelperTest < ActionView::TestCase
  include ApplicationHelper
  include ModalFields

  # Every taxonomy's editor, in the order the browser builds it. The shared seven
  # come first, the photo next, and a taxonomy's own fields last — which is why a
  # content tag's `show_in_menu` and a Relation tag's `symmetric`/`inverse` sit
  # after the photo rather than beside their nearest sibling.
  #
  # This table is deliberately explicit rather than derived. It is the contract:
  # a field added to one taxonomy's editor and not to another's is exactly the
  # drift these tests exist to fail on.
  SHARED_TAG_FIELDS = %w[name description bgcolor fgcolor parent_id taggable].freeze

  TAG_FIELDS_BY_TYPE = {
    "character" => SHARED_TAG_FIELDS + %w[photo show_in_menu],
    "event" => SHARED_TAG_FIELDS + %w[photo show_in_menu],
    "item" => SHARED_TAG_FIELDS + %w[photo show_in_menu],
    "location" => SHARED_TAG_FIELDS + %w[photo show_in_menu],
    "relation" => SHARED_TAG_FIELDS + %w[photo symmetric inverse],
    "ownership" => SHARED_TAG_FIELDS + %w[photo],
    "section" => SHARED_TAG_FIELDS + %w[photo],
    "scene" => SHARED_TAG_FIELDS + %w[photo]
  }.freeze

  # What each serializer has to carry, in its own declaration order. The keys are
  # the editor's field names, so a field the form renders but the serializer
  # omits cannot be prefilled, and a key the form does not render submits a value
  # the author never chose. `photo_url` is the one key that is not a column: it
  # names the record's stored image so the shared photo control can show what it
  # is about to replace.
  SERIALIZED_KEYS = {
    "character" => %w[name description character_tag_ids photo_url],
    "item" => %w[name description item_tag_ids photo_url],
    "event" => %w[title start_datetime end_datetime before_event_id after_event_id
                  simultaneous_event_id description event_tag_ids photo_url],
    "relation" => %w[name character1_id character2_id relation_tag_ids description
                     from_date to_date photo_url],
    "ownership" => %w[name item_id character_id ownership_tag_ids description
                      from_date to_date photo_url]
  }.freeze

  setup do
    @universe = universes(:universe_one)
  end

  test "an Event's datetimes keep the seconds they were stored with" do
    event = Event.create!(universe: @universe, title: "Precise",
      start_datetime: Time.utc(2026, 9, 11, 9, 0, 30), end_datetime: Time.utc(2026, 9, 11, 10, 15, 45))

    assert_equal "2026-09-11T09:00:30", serialized(event)["start_datetime"]
    assert_equal "2026-09-11T10:15:45", serialized(event)["end_datetime"]
  end

  test "a Relation's interval keeps its seconds and carries the optional name" do
    relation = Relation.create!(universe: @universe, character1: characters(:character_one),
      character2: characters(:character_two), name: "Family", from_date: Time.utc(2026, 1, 2, 3, 4, 5),
      to_date: Time.utc(2027, 1, 2, 3, 4, 6))

    assert_equal "Family", serialized(relation)["name"]
    assert_equal "2026-01-02T03:04:05", serialized(relation)["from_date"]
    assert_equal "2027-01-02T03:04:06", serialized(relation)["to_date"]
  end

  test "an Ownership's interval keeps its seconds and carries the optional name" do
    ownership = Ownership.create!(universe: @universe, item: items(:item_one),
      character: characters(:character_one), name: "Heirloom", from_date: Time.utc(2026, 1, 2, 3, 4, 5),
      to_date: Time.utc(2027, 1, 2, 3, 4, 6))

    assert_equal "Heirloom", serialized(ownership)["name"]
    assert_equal "2026-01-02T03:04:05", serialized(ownership)["from_date"]
    assert_equal "2027-01-02T03:04:06", serialized(ownership)["to_date"]
  end

  test "an unset datetime and name serialize as nil, so the editor opens empty" do
    relation = Relation.create!(universe: @universe, character1: characters(:character_one),
      character2: characters(:character_two))

    assert_nil serialized(relation)["name"]
    assert_nil serialized(relation)["from_date"]
    assert_nil serialized(relation)["to_date"]
    assert_nil serialized(Relation.new)["name"]
  end

  test "the shared format keeps the second the display format leaves out" do
    # Two formats, two jobs: `DATE_FORMAT` is what a reader is shown, and
    # `DATETIME_LOCAL_FORMAT` is what a `datetime-local` control is handed. Only
    # the second one has to keep seconds, because a control whose step is a whole
    # minute cannot hold one and would drop it on save.
    stored = Time.utc(2026, 9, 11, 9, 30, 45)

    assert_equal "2026-09-11 09:30", stored.strftime(ApplicationHelper::DATE_FORMAT)
    assert_equal "2026-09-11T09:30:45", stored.strftime(ApplicationHelper::DATETIME_LOCAL_FORMAT)
  end

  test "each serializer carries a fixed key set, with the photo last" do
    relation = Relation.create!(universe: @universe, character1: characters(:character_one),
      character2: characters(:character_two))
    ownership = Ownership.create!(universe: @universe, item: items(:item_one),
      character: characters(:character_one))

    records = {
      "character" => characters(:character_one),
      "item" => items(:item_one),
      "event" => events(:event_one),
      "relation" => relation,
      "ownership" => ownership
    }

    records.each do |type, record|
      assert_equal SERIALIZED_KEYS.fetch(type), serialized(record).keys,
        "#{type}'s serializer keys"
    end
  end

  test "a serializer's tag ids are the assigned ids, not their names" do
    character = characters(:character_one)

    assert_equal [ character_tags(:character_tag_one).id ], serialized(character)["character_tag_ids"]
  end

  test "every taxonomy's editor is the shared fields plus its own" do
    TAG_FIELDS_BY_TYPE.each do |type, expected|
      fields = public_send(:"#{type}_tag_taxonomy_fields", [])

      assert_equal expected, fields.map { |field| field[:name] }, "#{type} editor fields"
    end
  end

  test "every taxonomy editor field is a column its own tag table has" do
    # `shared/_taxonomy_node` serializes one prefill value per descriptor by
    # calling `node.public_send(field[:name])`, so a descriptor naming a column
    # the table does not have is a `NoMethodError` in the middle of rendering a
    # page, not a missing field. The photo is the one descriptor that names
    # something a column cannot answer, which is what its `url` flag is for.
    TAG_FIELDS_BY_TYPE.each do |type, _expected|
      model = tag_model(type)

      public_send(:"#{type}_tag_taxonomy_fields", []).each do |field|
        if field[:url]
          assert_equal "photo", field[:name], "#{type}'s url descriptor is the photo"
        else
          assert model.column_names.include?(field[:name]),
            "#{type}'s editor offers #{field[:name].inspect}, which #{model.table_name} has no such column for"
        end
      end
    end
  end

  test "the photo descriptor is one widget every photo-capable editor carries" do
    # `url: true` is what tells the tree to serialize the record's own photo URL
    # instead of reading a column, and it is the reason `photo_field` cannot be a
    # frozen hash of translated copy: the label has to cross the boundary already
    # translated, so the constant holds a key and this resolves it per request.
    field = photo_field

    assert_equal %i[name type url label], field.keys
    assert_equal "photo", field[:type]
    assert field[:url]
    assert_equal I18n.t("modal_fields.photo"), field[:label]

    # The same descriptor, reached through the shared builder every taxonomy
    # goes through and through the two hand-maintained nested-record editors.
    assert_equal field, taxonomy_tag_fields([]).find { |candidate| candidate[:name] == "photo" }
    assert_equal field, location_taxonomy_fields([]).find { |candidate| candidate[:name] == "photo" }
    assert_equal field, section_taxonomy_fields([]).find { |candidate| candidate[:name] == "photo" }
  end

  test "no descriptor carries the key it was translated from" do
    # `label_key` is how the label is found, not part of the contract with the
    # tree controller. Leaving it in the serialized JSON would publish a key
    # nobody renders, and it is the kind of thing a copy/paste of a sibling
    # descriptor reintroduces without anyone noticing.
    all_descriptors.each do |field|
      assert_not field.key?(:label_key), "#{field[:name]} serialized its label_key"
      assert_predicate field[:label], :present?, "#{field[:name]} has no resolved label"
    end
  end

  test "the two nested-record editors are the same five descriptors" do
    # Location and Section are the two editors that carry a parent selector and a
    # tag selector, and they are hand-maintained separately. They must stay the
    # same editor apart from which taxonomy the selector reads: the two pages
    # share one reader, one tree, and one photo widget.
    locations = location_taxonomy_fields([])
    sections = section_taxonomy_fields([])

    assert_equal %w[name description parent_id location_tag_ids photo], locations.map { |field| field[:name] }
    assert_equal %w[name description parent_id section_tag_ids photo], sections.map { |field| field[:name] }
    assert_equal locations.map { |field| field[:type] }, sections.map { |field| field[:type] }
    assert_equal locations.map { |field| field[:required] }, sections.map { |field| field[:required] }

    [ locations, sections ].each do |fields|
      selector = fields.find { |field| field[:type] == "select" && field[:multiple] }

      assert selector, "the tag selector is a multiple select in both editors"
    end
  end

  test "the nested-record tag selector offers the tag's id and its own name" do
    # The option value is an id and the option text is the author's own words, so
    # neither is translated; only the selector's own label is chrome.
    tag = location_tags(:location_tag_one)
    selector = location_taxonomy_fields([ tag ]).find { |field| field[:name] == "location_tag_ids" }

    assert_equal [ [ tag.id, tag.name ] ], selector[:options]
    assert_equal I18n.t("modal_fields.location_tags"), selector[:label]
  end

  test "the parent selector offers the blank option first and indents by depth" do
    # The blank option's *value* is the empty string the form stores and its label
    # is chrome. Every other option is depth-indented with an em-dash prefix, so a
    # child is visibly a child and two records called "Room" are not ambiguous.
    root = Location.create!(universe: @universe, name: "Keep")
    child = Location.create!(universe: @universe, name: "Tower", parent: root)
    grandchild = Location.create!(universe: @universe, name: "Cellar", parent: child)

    options = taxonomy_parent_options([ grandchild, child, root ])

    assert_equal [ "", "(No parent)" ], options.first
    assert_equal [ [ root.id, "Keep" ], [ child.id, "— Tower" ], [ grandchild.id, "— — Cellar" ] ],
      options.drop(1)
  end

  test "an empty parent selector is the blank option and nothing else" do
    # A taxonomy's first tag has nothing to be a child of, and a nested-record
    # editor with no siblings still has to offer the blank option — otherwise the
    # selector renders empty and the reader cannot tell "no parent" from "no
    # choice".
    assert_equal [ [ "", "(No parent)" ] ], taxonomy_parent_options([])

    [ location_taxonomy_fields([]), section_taxonomy_fields([]) ].each do |fields|
      assert_equal [ [ "", "(No parent)" ] ],
        fields.find { |field| field[:name] == "parent_id" }[:options]
    end
  end

  private
    def tag_model(type)
      "#{type}_tag".classify.constantize
    end

    def all_descriptors
      TAG_FIELDS_BY_TYPE.keys.flat_map { |type| public_send(:"#{type}_tag_taxonomy_fields", []) } +
        content_tag_taxonomy_fields([]) +
        location_taxonomy_fields([]) +
        section_taxonomy_fields([])
    end

    def serialized(record)
      case record
      when Event then JSON.parse(event_fields_json(record))
      when Relation then JSON.parse(relation_fields_json(record))
      when Ownership then JSON.parse(ownership_fields_json(record))
      when Character then JSON.parse(character_fields_json(record))
      when Item then JSON.parse(item_fields_json(record))
      end
    end
end
