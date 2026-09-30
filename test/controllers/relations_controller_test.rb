require "test_helper"

class RelationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @character_one = characters(:character_one)
    @character_two = characters(:character_two)
    @relation_tag = RelationTag.create!(universe: @universe, name: "Child of")
    sign_in_as(users(:user_one))
  end

  test "should get index with relation options" do
    get universe_relations_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Relations"
    assert_includes response.body, @character_one.name
    assert_includes response.body, @relation_tag.name
    assert_select "nav.content-tabs a.active[aria-current=page][href=?]",
      universe_relations_path(universe_slug: @universe.slug)
    assert_select "nav.content-tabs a[href=?]",
      universe_characters_path(universe_slug: @universe.slug), text: "Characters"
    assert_select "nav.content-tabs a[href=?]",
      universe_character_tag_path(universe_slug: @universe.slug, id: character_tags(:character_tag_one), from: "workspace"),
      text: "Character tag one"
  end

  test "should create relation and redirect" do
    assert_difference("Relation.count") do
      post universe_relations_url(universe_slug: @universe.slug), params: {
        relation: {
          character1_id: @character_one.id,
          character2_id: @character_two.id,
          relation_tag_ids: [ @relation_tag.id ],
          description: "They are family"
        }
      }
    end

    assert_redirected_to universe_relations_url(universe_slug: @universe.slug)
    assert_equal "They are family", Relation.order(:id).last.description
  end

  test "should create a relation without tags" do
    assert_difference("Relation.count") do
      post universe_relations_url(universe_slug: @universe.slug), params: {
        relation: {
          character1_id: @character_one.id,
          character2_id: @character_two.id,
          description: "No taxonomy needed"
        }
      }
    end

    assert_redirected_to universe_relations_url(universe_slug: @universe.slug)
    assert_empty Relation.order(:id).last.relation_tags
  end

  test "should update relation and redirect" do
    relation = Relation.create!(universe: @universe, character1: @character_one, character2: @character_two, relation_tags: [ @relation_tag ])

    patch universe_relation_url(universe_slug: @universe.slug, id: relation), params: {
      relation: { description: "Updated description" }
    }

    assert_redirected_to universe_relations_url(universe_slug: @universe.slug)
    assert_equal "Updated description", relation.reload.description
  end

  test "a rejected create states the reason and keeps the entered values in the editor" do
    assert_no_difference("Relation.count") do
      post universe_relations_url(universe_slug: @universe.slug), params: {
        relation: { character1_id: @character_one.id, character2_id: "", description: "Kept for another try" }
      }
    end

    assert_response :unprocessable_content
    # The reason is stated on the page the author lands on, and again inside the
    # editor they reopen, because this workspace re-renders after a rejection.
    assert_select ".alert-danger[role=alert]", text: /prevented this relation from being saved/
    # The attribute name is named in `activerecord.attributes.relation`, so the
    # message reads "Character 2" rather than Rails' humanized "Character2".
    assert_select ".alert-danger[role=alert] li", text: /Character 2/
    assert_select "[data-modal-form-target='modal'] .alert-danger li", text: /Character 2/
    # The invalid values are serialized into the Add trigger, so reopening the
    # editor does not silently discard the entry.
    assert_select "button[data-action='modal-form#open'][data-modal-form-url=?][data-modal-form-values-value*=?]",
      universe_relations_path(universe_slug: @universe.slug), "Kept for another try"
  end

  test "a rejected update prefill reaches only the edited row" do
    relation = Relation.create!(universe: @universe, character1: @character_one, character2: @character_two)
    other = Relation.create!(universe: @universe, character1: @character_two, character2: @character_one, description: "Stored text")

    patch universe_relation_url(universe_slug: @universe.slug, id: relation), params: {
      relation: { character2_id: "", description: "Rejected text" }
    }

    assert_response :unprocessable_content
    assert_select ".row-actions button[data-action='modal-form#open'][data-modal-form-url=?][data-modal-form-values-value*=?]",
      universe_relation_path(universe_slug: @universe.slug, id: relation), "Rejected text"
    assert_select ".row-actions button[data-action='modal-form#open'][data-modal-form-url=?][data-modal-form-values-value*=?]",
      universe_relation_path(universe_slug: @universe.slug, id: other), "Stored text", count: 1
  end
end
