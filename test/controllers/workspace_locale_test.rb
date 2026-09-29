require "test_helper"

# The Universe and Story workspaces rendered in Spanish.
#
# These are request tests rather than assertions on `I18n.locale`: the contract a
# reader depends on is the *rendered page*, and a locale that is set but not
# threaded into a view, a helper, or a controller flash is invisible to a locale
# assertion. Each case therefore reads the strings the page actually renders.
#
# They are not a check that a Spanish page contains no English at all — author
# data (a universe name, a story name, a tag name) is never translated, and the
# four Stimulus controllers still hardcode their own copy until the client-side
# slice. What is asserted is that the workspace's own chrome came from the
# Spanish keys, and that the access levels and query values that travel in a
# form field or a URL did *not* get translated along with their labels.
class WorkspaceLocaleTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
    patch settings_url, params: { locale: "es" }
  end

  test "the universes list, its empty state, and its columns are Spanish" do
    get universes_url

    assert_response :success
    assert_equal "es", rendered_lang
    assert_select "h1", text: "Universos"
    assert_select ".page-description", text: /Elige un mundo/
    assert_select "a.btn-primary", text: /Nuevo universo/
    assert_select "th", text: "Universo"
    assert_select "th", text: "Visibilidad"
    assert_select "th", text: "Acciones"
    assert_select ".badge", text: "Público"
    # Author data is never translated: the universe's own name still reads as its
    # owner typed it.
    assert_select "a.fw-semibold", text: @universe.name
  end

  test "the universes list tells a signed-in reader to create one" do
    Universe.find_each(&:soft_delete)

    get universes_url

    assert_response :success
    assert_select ".empty-title", text: "Crea tu primer universo"
    assert_select ".empty-description", text: /Un universo contiene el mundo/
  end

  test "the universes list tells a guest to wait for a public one" do
    Universe.find_each(&:soft_delete)
    sign_out

    get universes_url

    assert_response :success
    assert_select ".empty-title", text: "Todavía no hay universos públicos"
    assert_select ".empty-description", text: /Inicia sesión para crear un universo/
  end

  test "a universe page states its own stories, shared world, and actions in Spanish" do
    get universe_url(@universe)

    assert_response :success
    assert_equal @universe.name, rendered_title
    assert_select ".page-eyebrow", text: "Universo"
    assert_select ".page-description", text: /El mundo compartido/
    assert_select ".page-actions a", text: "Nueva historia"
    assert_select ".page-actions a", text: "Todas las historias"
    assert_select ".page-actions a", text: "Miembros"
    assert_select ".dropdown-toggle", text: ""
    assert_select ".page-eyebrow", text: "Historias"
    # The count is resolved with a `count:`, so the plural comes from the locale
    # rather than from appending an "s".
    assert_select "h2#universe-stories-title", text: "2 historias"
    assert_select ".page-eyebrow", text: "Biblia del universo"
    assert_select "h2", text: "Mundo compartido"
    assert_select "a[href=?]", universe_characters_path, text: "Personajes"
    assert_select "a[href=?]", universe_timeline_path, text: "Cronología"
  end

  test "a universe page names each story and its story-named open action" do
    get universe_url(@universe)

    assert_response :success
    assert_select "a.entity-title", text: "Story One"
    assert_select "a.entity-title", text: "Spin-off"
    assert_select "a.btn-outline-primary[aria-label=?]", "Abrir Story One", text: "Abrir"
  end

  test "a universe with no stories says so, and offers the writer a way to fix it" do
    @universe.stories.each(&:soft_delete)

    get universe_url(@universe)

    assert_response :success
    assert_select ".empty-title", text: "Todavía no hay historias"
    assert_select ".empty-description", text: /Crea la primera/
  end

  test "the universe form labels, submit button, and hint are Spanish" do
    get new_universe_url

    assert_response :success
    assert_select "h1", text: "Nuevo universo"
    assert_select "label[for=universe_name]", text: "Nombre"
    assert_select "label[for=universe_slug]", text: "Slug de la dirección"
    assert_select ".form-text", text: /Déjalo en blanco para construir la dirección/
    assert_select ".form-check-label", text: "Universo privado"
    assert_select ".form-text", text: /Los universos públicos/
    assert_select "input[type=submit][value=?]", "Crear universo"
    assert_select "a.btn-link", text: "Cancelar"

    patch universe_url(@universe), params: { universe: { name: "Editado" } }

    # A rename changes the slug, and every path below it is keyed by that slug,
    # so the page under test has to be addressed through the renamed record.
    get edit_universe_url(@universe.reload)

    assert_response :success
    # The browser tab names the record; the page keeps the workspace's own title.
    assert_equal "Editar Editado", rendered_title
    assert_select "h1", text: "Editar universo"
    # The optional address field starts blank on the edit form too, and its hint
    # names the address the universe is published under right now.
    assert_select "input#universe_slug[value='']"
    assert_select ".form-text", text: /Déjalo en blanco para conservar \/u\/editado/
    assert_select "input[type=submit][value=?]", "Actualizar universo"
  end

  test "a taken universe address is reported in Spanish" do
    Universe.create!(owner: users(:user_one), name: "Ocupado", slug: "ocupado")

    post universes_url, params: { universe: { name: "Ocupado" } }

    assert_response :unprocessable_content
    assert_select ".alert-danger[role=alert] li", text: "Slug ya está en uso"
  end

  test "the stories list and its per-story actions are Spanish" do
    get universe_stories_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: "Historias"
    assert_select ".page-description", text: /Cada historia es dueña de su trama/
    assert_select ".page-actions a", text: "Nueva historia"
    assert_select ".story-card-title a", text: "Story One"
    assert_select "p.text-body-secondary", text: "The main story of universe one"
    assert_select "a.btn-primary", text: "Abrir historia"
    assert_select "a.btn-outline-secondary", text: "Secciones"
    assert_select ".dropdown-item", text: "Editar historia"
    assert_select ".dropdown-item.text-danger", text: "Eliminar historia"
  end

  test "a story with no description says so instead of leaving a gap" do
    @story.update_column(:description, nil)

    get universe_stories_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "p.text-body-secondary", text: "Todavía no hay descripción."
  end

  test "a story page states its structure and its shared world in Spanish" do
    get universe_story_url(universe_slug: @universe.slug, id: @story)

    assert_response :success
    assert_equal @story.name, rendered_title
    assert_select ".page-eyebrow", text: "Espacio de trabajo de la historia"
    assert_select ".page-actions a", text: "Abrir las secciones"
    assert_select ".page-actions a", text: "Abrir las escenas"
    assert_select ".page-actions a", text: "Editar historia"
    assert_select ".page-eyebrow", text: "Estructura de la historia"
    assert_select ".page-eyebrow", text: "Biblia del universo compartida"
    assert_select "h2", text: "Registros de construcción del mundo"
    # The universe's name is interpolated into a translated sentence, so the
    # sentence reads in Spanish around data that is not translated.
    assert_select ".col-md-7 p.text-body-secondary", text: /Todas las historias de Universe one comparten estos registros/
    assert_select "a.quick-link", text: "Cronología"
  end

  test "a story with no description falls back to translated copy" do
    @story.update_column(:description, nil)

    get universe_story_url(universe_slug: @universe.slug, id: @story)

    assert_response :success
    assert_select ".page-description", text: "Planifica la trama y la estructura de esta historia."
  end

  test "the story form labels and submit button are Spanish" do
    get new_universe_story_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: "Nueva historia"
    assert_select "label[for=story_name]", text: "Nombre"
    assert_select "label[for=story_description]", text: "Descripción"
    assert_select "input[type=submit][value=?]", "Crear historia"
    assert_select "a.btn-link", text: "Cancelar"

    get edit_universe_story_url(universe_slug: @universe.slug, id: @story)

    assert_response :success
    assert_select "input[type=submit][value=?]", "Actualizar historia"
  end

  test "the Members page and the add-member page are Spanish" do
    UniverseMembership.create!(universe: @universe, user: users(:user_two), access_level: :write)

    get universe_memberships_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: "Miembros"
    assert_select ".page-description", text: /Concede acceso de lectura/
    assert_select ".page-actions a", text: "Volver al universo"
    assert_select ".page-eyebrow", text: "Conceder acceso"
    assert_select "h2", text: "Añadir un miembro"
    assert_select "th", text: "Miembro"
    assert_select "th", text: "Acceso"
    assert_select "th", text: "Acciones"
    assert_select "label[for=membership_email_address]", text: "Dirección de correo"
    assert_select "label[for=membership_access_level]", text: "Nivel de acceso"
    assert_select "input[type=submit][value=?]", "Conceder acceso"
    assert_select "td.text-end", text: "Propietario"
    # The badge label is translated; the access level the form stores is not.
    assert_select ".badge", text: "Escritura"
    assert_select "form select[name='membership[access_level]'] option[value=write]", text: "Escritura"
    assert_select "form select[name='membership[access_level]'] option[value=admin]", text: "Administración"
    assert_select "input[type=submit][value=?]", "Guardar"
    assert_select "button.btn-outline-danger", text: "Quitar"

    get new_universe_membership_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: "Añadir miembro"
    assert_select "a.btn-link", text: "Cancelar"
  end

  test "a refused membership states its reason in Spanish" do
    post universe_memberships_url(universe_slug: @universe.slug),
      params: { membership: { email_address: "missing@example.com", access_level: "read" } }

    assert_response :unprocessable_content
    assert_select ".alert-danger", text: /Un error impidió guardar este acceso/
    assert_select ".alert-danger", text: /Dirección de correo no se ha encontrado/
  end

  test "a membership grant confirms itself in Spanish" do
    post universe_memberships_url(universe_slug: @universe.slug),
      params: { membership: { email_address: users(:user_two).email_address, access_level: "read" } }

    assert_response :see_other
    assert_equal "El acceso del miembro se ha concedido correctamente.", flash[:notice]
  end

  test "the Sections tree and a Section's own page are Spanish" do
    get universe_story_sections_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_select "h1", text: "Secciones"
    assert_select ".page-eyebrow", text: "Historia: Story One"
    assert_select ".page-description", text: /Organiza esta historia en una jerarquía/
    assert_select ".page-actions button", text: "Añadir sección"
    assert_select "nav.content-tabs a", text: "Secciones"
    assert_select "nav.content-tabs a", text: "Escenas"

    get universe_story_section_url(universe_slug: @universe.slug, story_id: @story, id: sections(:section_one))

    assert_response :success
    assert_select ".page-eyebrow", text: "Sección"
    assert_select "h2", text: "Escenas de esta sección"
    assert_select "h2", text: "Información relacionada"
    # Each fact's own label, and each blank state's own copy.
    assert_select "dt", text: "Historia"
    assert_select "dt", text: "Ruta de la sección"
    assert_select "dt", text: "Etiquetas de sección"
    assert_select "dt", text: "Descripción"
    assert_select ".page-actions a", text: "Todas las secciones"
  end

  test "the taxonomy workspace and its scope tabs are Spanish" do
    get universe_story_url(universe_slug: @universe.slug, id: @story)
    get universe_tags_url(universe_slug: @universe.slug, scope: "story", taxonomy: "scene")

    assert_response :success
    assert_select "h1", text: "Etiquetas"
    assert_select ".page-eyebrow", text: "Etiquetas de historia"
    assert_select ".tag-scope-tabs a.active", text: "Etiquetas de historia"
    assert_select ".tag-taxonomy-tabs a.active", text: "Etiquetas de escenas"
    assert_select ".tag-taxonomy-tabs a", text: "Etiquetas de secciones"
    assert_select ".page-description", text: /Define etiquetas opcionales para las escenas/
    assert_select ".page-actions button", text: "Añadir etiqueta de escena"
  end

  test "a taxonomy node's delete confirmation is Spanish and names the tag" do
    get universe_story_url(universe_slug: @universe.slug, id: @story)
    get universe_tags_url(universe_slug: @universe.slug, scope: "story", taxonomy: "scene")

    assert_response :success
    # The confirmation travels to the taxonomy tree as a per-node attribute, so
    # it is read from the DOM rather than from a rendered button.
    assert_select ".taxonomy-node[data-confirm-message=?]",
      "¿Eliminar «Scene tag one»? Sus etiquetas hijas y sus asignaciones se eliminarán. Las escenas se conservarán."
    # The tag's own name is data and is interpolated, not translated.
    assert_select ".taxonomy-node .badge", text: "Scene tag one"
  end

  test "a Sections node's delete confirmation is Spanish and states the consequences" do
    get universe_story_sections_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_select ".taxonomy-node[data-confirm-message=?]",
      "¿Eliminar «Section one»? Sus secciones hijas y las asignaciones de etiquetas se eliminarán, y las escenas vinculadas quedarán sin agrupar. Su orden narrativo no cambiará."
  end

  test "the universe-scope taxonomy workspace is Spanish" do
    get universe_tags_url(universe_slug: @universe.slug, scope: "universe", taxonomy: "character")

    assert_response :success
    assert_select "h1", text: "Etiquetas"
    assert_select ".page-eyebrow", text: "Etiquetas del universo"
    assert_select ".tag-taxonomy-tabs a.active", text: "Etiquetas de personajes"
    assert_select ".page-description", text: /Define las etiquetas opcionales que sirven para organizar a los personajes/
    assert_select ".page-actions button", text: "Añadir etiqueta de personaje"
    # A universe-scope taxonomy has no confirmation of its own, so the tree node
    # carries no `data-confirm-message` at all.
    assert_select ".taxonomy-node[data-confirm-message]", count: 0
  end

  test "the taxonomy workspace asks for a story before offering story tags" do
    get universe_tags_url(universe_slug: @universe.slug, scope: "story", taxonomy: "scene")

    assert_response :success
    assert_select "h1", text: "Etiquetas"
    assert_select ".empty-title", text: "Selecciona una historia"
    assert_select ".empty-description", text: /Las etiquetas de historia pertenecen a una historia concreta/
  end

  test "the Timeline, its empty state, and its per-event popover are Spanish" do
    get universe_timeline_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: "Cronología"
    assert_select ".page-eyebrow", text: "Biblia del universo"
    assert_select ".page-description", text: /Descubre cómo se ordenan los sucesos/
    assert_select ".page-actions a", text: "Añadir suceso"
    # The popover's own labels are assembled by TimelineHelper, which is the part
    # a grep of the view cannot see. The node's own text is the event's id, which
    # is data.
    assert_select ".timeline-node", text: events(:event_one).id.to_s
    assert_select ".timeline-node[data-bs-title=?]", "The beginning"
    assert_select ".timeline-node[data-bs-content*=?]", "Fechas:"
  end

  test "an empty timeline says why it is empty, by access level" do
    @universe.events.find_each(&:soft_delete)

    get universe_timeline_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".empty-title", text: "No hay sucesos que colocar en la cronología"
    assert_select ".empty-description", text: /Añade sucesos con fechas/
  end

  test "the create and update confirmations are written in the chosen language" do
    assert_difference("Universe.count") do
      post universes_url, params: { universe: { name: "Universo en español" } }
    end

    assert_equal "El universo se ha creado correctamente.", flash[:notice]

    patch universe_url(Universe.last), params: { universe: { name: "Renombrado" } }

    assert_response :see_other
    assert_equal "El universo se ha actualizado correctamente.", flash[:notice]

    assert_difference("Universe.count", -1) do
      delete universe_url(Universe.last)
    end

    assert_response :see_other
    assert_equal "El universo se ha eliminado correctamente.", flash[:notice]
  end

  test "a story's create and delete confirmations are Spanish" do
    assert_difference("Story.count") do
      post universe_stories_url(universe_slug: @universe.slug), params: { story: { name: "Historia nueva" } }
    end

    assert_equal "La historia se ha creado correctamente.", flash[:notice]

    assert_difference("Story.count", -1) do
      delete universe_story_url(universe_slug: @universe.slug, id: Story.order(:id).last)
    end

    assert_response :see_other
    assert_equal "La historia se ha eliminado correctamente.", flash[:notice]
  end

  private
    def rendered_lang
      Nokogiri::HTML(response.body).at_css("html")["lang"]
    end

    def rendered_title
      Nokogiri::HTML(response.body).at_css("title").text
    end
end
