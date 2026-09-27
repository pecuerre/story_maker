require "test_helper"

# One searchable document per declared model, and the rules the engine enforces
# on a document id. These are the assertions that keep a silent index failure
# from shipping: an id Meilisearch refuses is invisible everywhere except its own
# task log, and two models sharing an id overwrite one another without any error
# at all.
class SearchableTest < ActiveSupport::TestCase
  # Meilisearch accepts only alphanumerics, hyphens, and underscores in a document
  # id, and refuses the whole batch when one document breaks the rule.
  VALID_ID = /\A[A-Za-z0-9_-]+\z/

  test "every registered model declares what is searchable" do
    Search::Registry::MODELS.each do |model|
      assert model.searchable?, "#{model.name} is in the search registry but declares nothing"
      assert model.search_declaration.kind.present?, "#{model.name} declares no kind"
      assert model.search_declaration.title.present?, "#{model.name} declares no searchable title field"
    end
  end

  test "every registered model's document is acceptable to the engine" do
    Search::Registry::MODELS.each do |model|
      record = record_for(model)
      next if record.nil?

      document = record.search_document

      assert_match VALID_ID, document[:id], "#{model.name} produced an unusable document id"
      assert document[:kind].present?, "#{model.name} produced a document with no kind"
      assert document[:url].present?, "#{model.name} produced a document with no url"
      assert document[:universe_id].present?, "#{model.name} produced a document with no universe to filter by"
      assert_includes Search::Kinds::LABELS.keys, document[:kind],
        "#{model.name} declares a kind the interface has no label for"
    end
  end

  test "a story-scoped document carries both the story and its universe" do
    scene = scenes(:scene_one)

    assert_equal "scene_element", SceneElement.search_declaration.kind
    assert_equal scenes(:scene_one).story_id, scene.search_document[:story_id]
    assert_equal universes(:universe_one).id, scene.search_document[:universe_id]
  end

  test "a universe is its own boundary" do
    universe = universes(:universe_one)
    document = universe.search_document

    assert_equal universe.id, document[:universe_id]
    assert_equal "/u/one", document[:url]
    assert_nil document[:story_id]
  end

  test "a record's document id names the model, so two models cannot collide" do
    # The eight taxonomies all search as "tag". A kind-based id would have made
    # Character Tag 1 and Location Tag 1 the same document.
    assert_equal "character_tag-#{character_tags(:character_tag_one).id}",
      character_tags(:character_tag_one).search_id
    assert_equal "location_tag-#{location_tags(:location_tag_one).id}",
      location_tags(:location_tag_one).search_id

    ids = Search::Registry::MODELS.filter_map { |model| record_for(model)&.search_id }
    assert_equal ids.uniq.size, ids.size, "two records claimed the same document id"
  end

  test "a document holds ids rather than names, so a rename needs no reindex" do
    document = characters(:character_one).search_document

    assert_equal universes(:universe_one).id, document[:universe_id]
    assert_not_includes document.values.map(&:to_s), universes(:universe_one).name
  end

  test "a scene element's hit opens the scene that owns it" do
    element = scene_elements(:narration_one)
    document = element.search_document

    assert_equal "/u/one/s/#{scenes(:scene_one).story_id}/scenes/#{scenes(:scene_one).id}", document[:url]
    assert_equal "scene_element-#{element.id}", document[:id]
  end

  test "a link record is titled by its endpoints" do
    character = characters(:character_one)
    relation = Relation.create!(universe: universe_of(character), character1: character,
      character2: characters(:character_two), name: "Knows")

    assert_equal "Knows", relation.search_document[:title]
  end

  test "a blank field is an absent field rather than an empty string" do
    character = characters(:character_one)

    assert_nil character.search_document[:body]
    assert_equal "Character one", character.search_document[:title]
  end

  test "saving queues an index write carrying the committed document" do
    character = characters(:character_one)
    character.update!(description: "A wizard")

    document = nil
    assert_enqueued_with job: Search::IndexRecordJob, args: ->(args) { document = args.first }
    assert document.present?, "saving queued no index write"

    assert_equal character.search_id, document[:id]
    assert_equal "A wizard", document[:body]
  end

  test "destroying queues a removal by id, because the record is already gone" do
    character = characters(:character_one)
    search_id = character.search_id

    assert_enqueued_with job: Search::RemoveRecordJob, args: [ search_id ] do
      character.destroy!
    end
  end

  test "a rolled back save queues nothing" do
    character = characters(:character_one)

    assert_no_enqueued_jobs only: Search::IndexRecordJob do
      Character.transaction do
        character.update!(description: "Never committed")
        raise ActiveRecord::Rollback
      end
    end
  end

  test "a declaration without a route must build its own path" do
    assert_nil SceneElement.search_declaration.route
    assert_raises(ArgumentError) { SceneElement.search_declaration.route! }
    assert_equal "character", Character.search_declaration.route!
  end

  test "a declaration rejects what it cannot describe" do
    assert_raises(ArgumentError) { Searchable::Declaration.new(kind: nil, title: :name, route: "character") }
    assert_raises(ArgumentError) { Searchable::Declaration.new(kind: "character", title: :name, route: "character", scope: :nowhere) }
  end

  private
    def record_for(model)
      model.first
    end

    def universe_of(record)
      record.universe
    end
end
