require "test_helper"

# The Characters list rendered in Spanish: its search area, its three empty
# states, and the summaries that repeat the active filters.
#
# These are request tests rather than assertions on `I18n.locale`, for the reason
# `SceneWorkspaceLocaleTest` gives: the contract a reader depends on is the
# *rendered* page, and a locale that is set but not threaded into a view or a
# helper is invisible to a locale assertion.
#
# They are not a check that a Spanish page contains no English at all. Author data
# — a character name, a tag name — is never translated, and the values that travel
# in the `character_tag_id` and `sort` query parameters stay English whatever the
# reader's locale is. What is asserted is that the chrome came from the Spanish
# keys and that the query values did not get translated along with their labels.
class CharacterWorkspaceLocaleTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @character = characters(:character_one)
    sign_in_as(users(:user_one))
    patch settings_url, params: { locale: "es" }
  end

  test "the Characters search area and its options are Spanish" do
    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: "Personajes"
    assert_select ".character-filter h2", text: "Buscar personajes"
    assert_select ".character-filter label[for=character_filter_q]", text: "Buscar"
    assert_select ".character-filter input[name=q][placeholder=?]", "Nombre o descripción"
    assert_select ".character-filter label[for=character_filter_character_tag_id]", text: "Etiqueta de personaje"
    assert_select ".character-filter label[for=character_filter_sort]", text: "Orden"
    assert_select ".character-filter input[type=submit][value=?]", "Filtrar personajes"
    assert_select ".character-filter option", text: "Todas las etiquetas de personajes"
  end

  test "a tag's own name stays the author's, while the path beside it is chrome" do
    get universe_characters_url(universe_slug: @universe.slug)

    assert_select "select[name=character_tag_id] option", text: "Character tag one"
    assert_select "select[name=character_tag_id] option",
      { text: "Character tag one / Character tag child" },
      "the separator and the labels come from the locale, the tag names do not"
  end

  test "the order options are Spanish while the order values stay English" do
    get universe_characters_url(universe_slug: @universe.slug, sort: "created")

    assert_response :success
    assert_select "select[name=sort] option[value=created][selected]", text: "Más recientes primero"
    assert_select "select[name=sort] option[value=name]", text: "Nombre (de la A a la Z)"
    # `created` is the value that travels in the URL, so it is untranslated; the
    # sentence beside it is chrome.
    assert_select ".character-filter .badge", text: "Orden: Más recientes primero"
  end

  test "a filtered empty result is Spanish and repeats the filter that produced it" do
    get universe_characters_url(universe_slug: @universe.slug, q: "cave")

    assert_response :success
    assert_select ".empty-title", text: "Ningún personaje coincide con estos filtros"
    # The universe's own name is the author's record name and is interpolated into
    # the Spanish sentence rather than translated with it.
    assert_select ".empty-description", text: /Universe one tiene 3 personajes, pero ninguno coincide/
    assert_select ".empty-state .badge", text: "Búsqueda: «cave»"
    assert_select ".empty-state a", text: "Quitar filtros"
  end

  test "the unfiltered empty state is Spanish" do
    @universe.characters.destroy_all

    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".empty-title", text: "Todavía no hay personajes"
  end

  test "a discarded filter value is reported in Spanish" do
    get universe_characters_url(universe_slug: @universe.slug,
      character_tag_id: character_tags(:character_tag_three).id)

    assert_response :success
    assert_select ".alert", text: /Se ha ignorado el filtro de etiqueta de personaje/
  end
end
