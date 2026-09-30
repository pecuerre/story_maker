require "test_helper"

# The search surface in Spanish: the results page, the scope dropdown the top bar
# and that page share, the dropdown's JSON answer, the navigation commands, and
# the values a request could not use.
#
# These are request tests rather than assertions on `I18n.locale`, for the reason
# `WorkspaceLocaleTest` gives: the contract a reader depends on is the *rendered*
# page, and a locale that is set but not threaded into a view, a helper, or a
# model is invisible to a locale assertion.
#
# They are not a check that a Spanish page contains no English at all. Author data
# — a record's own name, a universe's name — is never translated, and a **search
# result row** shows the stored document title rather than a re-translated label.
# That last one is a decision, not an oversight: see
# `docs/features/search.md#a-result-row-shows-the-stored-document-title`.
class SearchesLocaleTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
    patch settings_url, params: { locale: "es" }
  end

  # A hit as the engine would answer it, in the universe the request is scoped to.
  def hit(title: "Hannah", kind: "character", taxonomy: nil, id: "#{kind}-1",
    url: "/u/#{@universe.slug}/characters/1", body: "A mother who disappears")
    SearchTestBackend.document(
      id: id, kind: kind, taxonomy: taxonomy, title: title,
      universe_id: @universe.id, body: body, url: url
    )
  end

  test "the results page's own chrome is Spanish" do
    stub_search_backend(hits: [ hit ])

    get universe_search_url(universe_slug: @universe.slug), params: { q: "hannah" }

    assert_response :success
    assert_equal "Buscar", rendered_title
    assert_select "h1", text: "Buscar"
    assert_select ".page-eyebrow", text: "Encuentra cualquier cosa"
    assert_select ".page-description", text: /Busca en todos los registros del alcance/
    assert_select "label[for=search_page_q]", text: "Buscar"
    # `minimum` is `Search::Query::MINIMUM_LENGTH`, a number the code owns.
    assert_select "input#search_page_q[placeholder=?]", "Al menos 2 caracteres"
    assert_select "label[for=search_page_scope]", text: "Alcance"
    assert_select "input[type=submit][value=?]", "Buscar"
    assert_select "form a.btn-light[href=?]", universe_search_path(universe_slug: @universe.slug),
      text: "Limpiar"
  end

  test "the form says what it searched, in a sentence that carries its own emphasis" do
    stub_search_backend(hits: [ hit ])

    get universe_search_url(universe_slug: @universe.slug), params: { q: "hannah" }

    assert_response :success
    # The scope is an interpolated label inside one `_html` sentence, so the
    # locale places the emphasis rather than the template wrapping a `<strong>`
    # around a translated word.
    assert_select ".search-page-scope-note", text: "Buscando Este universo."
    assert_select ".search-page-scope-note strong", text: "Este universo"
  end

  test "the scope dropdown offers the same fourteen scopes with Spanish labels and English values" do
    stub_search_backend

    get universe_search_url(universe_slug: @universe.slug)

    assert_response :success
    # A scope's value travels in a URL and is never translated: a link to
    # `?scope=characters` has to keep working in every language. The page's own
    # dropdown is counted apart from the top bar's, which renders the same list.
    assert_select ".search-page-form select[name=scope] option", Search::Scope::VALUES.size
    assert_select ".search-page-form select[name=scope] option[value=universe][selected]", text: "Este universo"
    assert_select ".search-page-form select[name=scope] option[value=platform]", text: "Plataforma entera"
    assert_select ".search-page-form select[name=scope] option[value=story]", text: "Esta historia"
    assert_select ".search-page-form select[name=scope] option[value=characters]", text: "Solo personajes"
    assert_select ".search-page-form select[name=scope] option[value=tags]", text: "Solo etiquetas"
    assert_select ".search-page-form select[name=scope][aria-label=?]", "Alcance de la búsqueda"
    # And the top bar's own copy of the same control.
    assert_select "nav select[name=scope] option[value=characters]", text: "Solo personajes"
  end

  test "a result row's badge is the kind's own Spanish word" do
    stub_search_backend(hits: [
      hit(kind: "character"),
      hit(id: "tag-1", kind: "tag", taxonomy: "Character", title: "Bloodline", url: "/u/one/character_tags/1")
    ])

    get universe_search_url(universe_slug: @universe.slug), params: { q: "hannah" }

    assert_response :success
    assert_select ".search-result-kind", text: "Personaje"
    # A taxonomy is named as a whole phrase rather than the kind's word with a
    # lowercased noun in front of it, which is what a Spanish label needs.
    assert_select ".search-result-kind", text: "Etiqueta de personaje"
  end

  test "the count, its truncation, and the pagination are Spanish" do
    stub_search_backend(hits: [ hit ])

    get universe_search_url(universe_slug: @universe.slug), params: { q: "hannah" }

    assert_response :success
    assert_select "#search-results-title", text: "1 coincidencia"

    # The count is the engine's total and not the page's, so the plural comes from
    # the locale rather than from a page that lists fewer rows than there are
    # matches.
    stub_search_backend(hits: [ hit ], total: 40)
    get universe_search_url(universe_slug: @universe.slug), params: { q: "hannah" }

    assert_response :success
    assert_select "#search-results-title", text: "Mostrando 1 de 40 coincidencias"
    assert_select ".search-pagination-position", text: "Página 1"
    assert_select "nav.search-pagination a[rel=next]", text: "Siguiente"

    get universe_search_url(universe_slug: @universe.slug), params: { q: "hannah", page: "2" }

    assert_response :success
    assert_select "nav.search-pagination a[rel=prev]", text: "Anterior"
    assert_select ".search-pagination-position", text: "Página 2"
  end

  test "the three explaining states are Spanish" do
    stub_search_backend
    get universe_search_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".search-empty h2", text: "Busca en este universo"
    assert_select ".search-empty p", text: /Escribe al menos 2 caracteres/

    get universe_search_url(universe_slug: @universe.slug), params: { q: "h" }

    assert_response :success
    assert_select ".search-empty h2", text: "Sigue escribiendo"
    assert_select ".search-empty p", text: /necesita al menos 2 caracteres/

    stub_search_backend(available: false)
    get universe_search_url(universe_slug: @universe.slug), params: { q: "hannah" }

    assert_response :success
    assert_select ".search-empty h2", text: "La búsqueda no está disponible"
    # The operator's own sentence (`Search::UnavailableBackend::REASON`) is for a
    # log line and a reindex report; the page says the same thing in the reader's
    # language rather than answering a Spanish heading with English.
    assert_select ".search-empty p", text: "Configura MEILISEARCH_URL y ejecuta bin/rails search:reindex."
  end

  test "an empty answer states the scope it searched, in a form a sentence can start" do
    stub_search_backend

    get universe_search_url(universe_slug: @universe.slug), params: { q: "zzzznotathing" }

    assert_response :success
    assert_select ".search-empty h2", text: "Nada coincide con «zzzznotathing»"
    # The scope is a sentence of its own rather than a noun inside the next one:
    # "Nada en *Este universo*" would need a lowercased label, and a lowercased
    # label is a word order the locale does not get to choose.
    assert_select ".search-empty p", text: "Se buscó Este universo. Comprueba la ortografía o amplía el alcance de arriba: «Plataforma entera» busca en todos los universos que puedes leer, no solo en este."

    # On the landing page there is no universe to widen into, so the sentence
    # without the platform hint is the honest one.
    get search_url, params: { q: "zzzznotathing" }

    assert_response :success
    assert_select ".search-empty h2", text: "Nada coincide con «zzzznotathing»"
    assert_select ".search-empty p", text: "Se buscó Plataforma entera. Comprueba la ortografía o prueba con otro alcance de arriba."
  end

  test "the navigation commands are Spanish, and their ids are not" do
    stub_search_backend(hits: [ hit ])

    get universe_search_url(universe_slug: @universe.slug), params: { q: "personajes" }

    assert_response :success
    assert_select ".search-commands h2", text: "Ir a"
    assert_select ".search-command", text: "Personajes"

    # The landing page's commands name a universe and say what opening one is.
    stub_search_backend
    get search_url(format: :json), params: { q: "universo" }

    assert_response :success
    commands = response.parsed_body["commands"]
    assert_includes commands.pluck("title"), "Universo: #{@universe.name}"
    assert_includes commands.pluck("subtitle"), "Abrir el universo"
    assert_includes commands.map { |command| command["id"] }, "universe-#{@universe.id}"
  end

  test "the JSON the dropdown asks for is Spanish" do
    stub_search_backend(hits: [ hit ])

    get universe_search_url(universe_slug: @universe.slug, format: :json), params: { q: "hannah" }

    assert_response :success
    payload = response.parsed_body

    # The scope label travels to the browser already translated, because the
    # controller builds the dropdown's copy from the same reader as the page.
    assert_equal "Este universo", payload["scope_label"]
    # `scope` is the query value and stays English, as it is in the form.
    assert_equal "universe", payload["scope"]
    assert_equal "Personaje", payload["results"].first["kind_label"]
  end

  test "a value a request could not use is reported in the reader's language" do
    stub_search_backend

    get universe_search_url(universe_slug: @universe.slug), params: { q: "hannah", scope: "planetas" }

    assert_response :success
    assert_select ".alert", text: "«planetas» no es un alcance de búsqueda, así que se usó el alcance por defecto."

    get universe_search_url(universe_slug: @universe.slug),
      params: { q: "hannah", scope: "story", story_id: stories(:story_two).id }

    assert_response :success
    # Two dropped values are joined in the reader's language, not with an English
    # connector, which is why each sentence is translated where it is dropped.
    assert_select ".alert", text: /El filtro de historia se ignoró porque no es una historia de este universo/
    assert_select ".alert", text: /La búsqueda por historia se amplió a este universo/
  end

  test "a story scope the page cannot honour says so in Spanish" do
    stub_search_backend

    get universe_search_url(universe_slug: @universe.slug), params: { q: "hannah", scope: "story" }

    assert_response :success
    assert_select ".alert", text: "La búsqueda por historia se amplió a este universo porque no hay ninguna historia seleccionada."
    # The control still shows what was really searched, and the request still
    # keeps the story scope in its URL.
    assert_select "form[action=?] select[name=scope] option[value=universe][selected]",
      universe_search_path(universe_slug: @universe.slug)
  end

  private
    def rendered_title
      Nokogiri::HTML(response.body).at_css("title").text
    end
end
