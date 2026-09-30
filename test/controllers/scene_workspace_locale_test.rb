require "test_helper"

# The Scene workspace rendered in Spanish: the story-scoped list and its filter,
# Scene Details with its Element list, the one editor `new` and `edit` share, the
# Characters, Items, and Locations tabs, the two story taxonomies, the Sections
# workspace's ungrouped block, the controller's flash copy, and the "Appears in
# scenes" section on a universe record's own page.
#
# These are request tests rather than assertions on `I18n.locale`, for the reason
# `WorkspaceLocaleTest` gives: the contract a reader depends on is the *rendered
# page*, and a locale that is set but not threaded into a view, a helper, a model,
# or a controller flash is invisible to a locale assertion.
#
# They are not a check that a Spanish page contains no English at all. Author data
# — a scene name, a tag name, a free-text role, an `Event#display_string` — is
# never translated, the value that travels in the `section_id` URL stays
# `ungrouped`, and the four Stimulus controllers still hardcode their own copy
# until the client-side slice. What is asserted is that each surface's own chrome
# came from the Spanish keys, and that the values that travel in a form field, an
# `<option>`, or a URL did *not* get translated along with their labels.
class SceneWorkspaceLocaleTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
    sign_in_as(users(:user_one))
    patch settings_url, params: { locale: "es" }
  end

  test "the Scenes list, its row badges, and its controls are Spanish" do
    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_equal "Escenas", rendered_title
    assert_select "h1", text: "Escenas"
    assert_select ".page-eyebrow", text: "Historia: Story One"
    assert_select ".page-description", text: /El orden de abajo es el orden en que se cuenta Story One/
    # The count is resolved with a `count:`, so the plural comes from the locale.
    assert_select ".page-header .badge[aria-label=?]", "3 escenas"
    assert_select "nav.content-tabs a.active", text: "Escenas"
    assert_select "nav.content-tabs a", text: "Secciones"
    assert_select ".page-actions a", text: "Añadir escena"
    # Author data is never translated: the scene's own name still reads as its
    # author typed it.
    assert_select ".entity-title", text: "Scene one"
  end

  test "a row's badges state their facts in Spanish and keep their values" do
    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_select ".entity-row .badge[aria-label=?]", "Posición narrativa 1 de 3"
    # Both counts are announced with their record type resolved from the locale.
    assert_select ".entity-row .badge[aria-label=?]", "4 elementos"
    assert_select ".entity-row .badge[aria-label=?]", "2 personajes participando"
    # The grouping badge names the Section path, which is author data, and reads
    # "Sin agrupar" for the scene that has none.
    assert_select ".entity-row .badge", text: "Sin agrupar"
    assert_select ".entity-row .badge[title=?]", "Agrupada bajo Section one. La agrupación no cambia el orden narrativo."
    assert_select ".entity-row .badge[title=?]",
      "Sin agrupar bajo ninguna sección. La agrupación no cambia el orden narrativo."
    # The move controls are boundary-aware and name the order they change.
    assert_select "form[action=?] button[disabled][title=?]",
      move_universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene),
      "Ya está la primera en el orden narrativo"
    assert_select "form[action=?] button[aria-label=?]",
      move_universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene),
      "Subir Scene one en el orden narrativo"
  end

  test "a row's delete confirmation is Spanish and names the record" do
    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    # The confirmation travels to the browser as a Turbo attribute, so it is read
    # from the DOM rather than from a rendered button. A Scene owns its Elements
    # and its presence links, so the cascade is stated rather than assumed.
    assert_select "form[action=?] button[data-turbo-confirm=?]",
      universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene),
      "¿Eliminar «Scene one»? Sus elementos, las asignaciones de etiquetas y los enlaces con " \
      "registros de la historia y del universo se eliminarán de forma permanente. Los registros " \
      "vinculados no se eliminarán."
  end

  test "the search area, its options, and its query values are Spanish" do
    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_select ".scene-filter h2", text: "Buscar escenas"
    assert_select "label[for=scene_filter_q]", text: "Buscar"
    assert_select "input[name=q][placeholder=?]", "Título o descripción breve"
    assert_select "label[for=scene_filter_section_id]", text: "Sección"
    assert_select "label[for=scene_filter_scene_tag_id]", text: "Etiqueta de escena"
    assert_select "label[for=scene_filter_from]", text: "En el mundo desde"
    assert_select "label[for=scene_filter_to]", text: "En el mundo hasta"
    assert_select "input[type=submit][value=?]", "Filtrar escenas"
    # The Ungrouped option's *value* is the query value that travels in the URL, so
    # it is the untranslated `ungrouped`; only its label is chrome.
    assert_select "select[name=section_id] option[value=?]", SceneFilter::UNGROUPED, text: "Sin agrupar"
    assert_select "select[name=section_id] option[value='']", text: "Todas las secciones"
    assert_select "select[name=scene_tag_id] option[value='']", text: "Todas las etiquetas de escenas"
    # The Section names are the author's own, and the tag paths are too.
    assert_select "select[name=section_id] option[value=?]", sections(:section_one).id, text: "Section one"
  end

  test "a narrowed list states its own counts and repeats the active filters" do
    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story,
      q: "second", section_id: sections(:section_two).id)

    assert_response :success
    assert_select ".scene-filter", text: /Mostrando 1 escena de 3 escenas/
    assert_select ".scene-filter span.d-block", text: /Filtrado por/
    # Each filter summary is its own sentence, so the label and the author's own
    # search text are interpolated into the locale's frame.
    assert_select ".scene-filter .badge", text: "Búsqueda: «second»"
    assert_select ".scene-filter .badge", text: "Sección: Section one / Section two"
  end

  test "a filter value that could not be used is reported in Spanish" do
    url = universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)

    get url, params: { section_id: sections(:section_alt).id }

    assert_response :success
    assert_select ".alert-danger", text: /Se ha ignorado el filtro de sección porque no es una sección de esta historia/

    get url, params: { scene_tag_id: scene_tags(:scene_tag_three).id }

    assert_response :success
    assert_select ".alert-danger", text: /Se ha ignorado el filtro de etiqueta de escena/

    get url, params: { from: "ayer" }

    assert_response :success
    # The bound is named by the locale's own word, not by the literal `start` this
    # object was constructed with.
    assert_select ".alert-danger", text: /No se ha podido leer la fecha de inicio en el mundo «ayer»/
  end

  test "an empty result and an empty story are two different Spanish states" do
    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story, q: "no such scene")

    assert_response :success
    assert_select ".empty-title", text: "Ninguna escena coincide con estos filtros"
    assert_select ".empty-description", text: /Story One tiene 3 escenas, pero ninguna coincide/
    assert_select ".empty-state a", text: "Quitar filtros"

    @story.scenes.destroy_all

    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_select ".empty-title", text: "Todavía no hay escenas"
    assert_select ".empty-description", text: /Añade la primera para empezar su orden narrativo/
  end

  test "Scene Details states its facts in Spanish" do
    @scene.update_column(:description, nil)

    get universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene)

    assert_response :success
    assert_equal @scene.name, rendered_title
    assert_select ".page-eyebrow", text: "Historia: Story One"
    assert_select ".page-description", text: /Escena 1 de 3 en el orden en que se cuenta Story One/
    assert_select ".page-actions a", text: "Todas las escenas"
    assert_select ".page-actions a", text: "Editar escena"
    assert_select ".page-eyebrow", text: "Posición narrativa"
    assert_select ".page-eyebrow", text: "Descripción breve"
    assert_select ".page-eyebrow", text: "Etiquetas de escena"
    assert_select ".page-eyebrow", text: "Grupo de sección"
    assert_select ".page-eyebrow", text: "Tiempo en el mundo"
    assert_select ".page-eyebrow", text: "Historia"
    assert_select ".page-description + .page-eyebrow, .col-12 p.text-body-secondary",
      text: "Todavía no hay descripción breve."
    # The scene tags are the author's own words, beside translated chrome.
    assert_select ".taxonomy-tag", text: "Scene tag one"
  end

  test "Scene Details states the facts a scene without references does not have" do
    get universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_three))

    assert_response :success
    assert_select ".col-12 p.text-body-secondary", text: /Sin agrupar\. Una Sección es opcional/
    assert_select ".col-12 p.text-body-secondary", text: "Todavía no hay ningún suceso enlazado."
    assert_select ".col-12 p.text-body-secondary", text: "Todavía no hay etiquetas de escena asignadas."
  end

  test "a linked event is named inside a Spanish sentence" do
    get universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene)

    assert_response :success
    # `Event#display_string` is the record's own label and is data, so it is
    # interpolated into the translated sentence rather than translated with it.
    assert_select ".col-12 p", text: /#{Regexp.escape(events(:event_one).display_string)}: consulta el/
    assert_select ".col-12 p a[href=?]", universe_events_path(universe_slug: @universe.slug),
      text: "espacio de trabajo de Sucesos"
  end

  test "the Element list, its badges, and its speaker note are Spanish" do
    get universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene)

    assert_response :success
    assert_select ".scene-elements h2", text: "Elementos de la escena"
    assert_select ".scene-elements .badge[aria-label=?]", "4 elementos"
    assert_select ".scene-elements .badge[aria-label=?]", "Elemento 1 de 4"
    # The kind is a stored value and is not translated; the label beside it is.
    assert_select ".scene-elements .badge", text: "Narración"
    assert_select ".scene-elements .badge", text: "Diálogo"
    assert_includes response.body, "Todavía no hay contenido"
    # The speaker note's verb agrees with the count, and the names are the
    # author's own.
    assert_includes response.body, "Character one y Character two hablan en este bloque"
    assert_includes response.body, "El enlace registra quién está en la conversación, no qué línea es de quién"
  end

  test "the element editor is Spanish and serializes its descriptions translated" do
    get universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene)

    assert_response :success
    assert_select "button[data-action='modal-form#open']", text: "Añadir elemento"
    assert_select ".modal-title", text: "Añadir elemento"
    assert_select "label[for=scene_element_kind]", text: "Tipo de elemento"
    assert_select "label[for=scene_element_name]", text: "Título"
    assert_select "label[for=scene_element_body]", text: "Contenido"
    assert_select "label[for=scene_element_character_ids]", text: "Hablantes"
    assert_select "input[type=submit][value=?]", "Guardar elemento"
    assert_select ".modal-footer button[data-bs-dismiss=modal]", text: "Cancelar"
    assert_select ".modal-header button.btn-close[aria-label=?]", "Cerrar"
    # The kind is a stored value; only the two labels beside it are translated.
    assert_select "select[name='scene_element[kind]'] option[value=?]", "narration", text: "Narración"
    assert_select "select[name='scene_element[kind]'] option[value=?]", "dialogue", text: "Diálogo"
    # The descriptions cross into the browser already translated, because the
    # browser prints them when the type changes.
    assert_equal({ "narration" => "Descripción o acción, sin que nadie hable.",
                   "dialogue" => "Un bloque hablado. Nombra a todos los que hablan en él." },
      scene_element_kind_descriptions)
  end

  test "the workspace tabs name the sibling workspaces' own titles" do
    get universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene)

    assert_response :success
    assert_select "nav.content-tabs[aria-label=?]", "Espacio de trabajo de la escena"
    assert_select "nav.content-tabs a.active", text: "Detalles de la escena"
    # The other three are the sibling workspaces' own titles rather than a second
    # copy of the same three words.
    assert_select "nav.content-tabs a[href=?]",
      universe_story_scene_scene_characters_path(universe_slug: @universe.slug, story_id: @story, scene_id: @scene),
      text: "Personajes"
    assert_select "nav.content-tabs a[href=?]",
      universe_story_scene_scene_items_path(universe_slug: @universe.slug, story_id: @story, scene_id: @scene),
      text: "Objetos"
    assert_select "nav.content-tabs a[href=?]",
      universe_story_scene_scene_locations_path(universe_slug: @universe.slug, story_id: @story, scene_id: @scene),
      text: "Lugares"
  end

  test "the Scene editor labels, hints, and submit buttons are Spanish" do
    get new_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_equal "Nueva escena", rendered_title
    assert_select "h1", text: "Nueva escena"
    assert_select ".page-description", text: /Añade la siguiente escena a Story One/
    assert_select "label[for=scene_name]", text: "Título"
    assert_select "label[for=scene_description]", text: "Descripción breve"
    assert_select "legend", text: "Etiquetas de escena"
    assert_select "label[for=scene_section_id]", text: "Sección"
    assert_select "legend", text: "Organización"
    assert_select "legend", text: "Tiempo en el mundo"
    assert_select "label[for=scene_event_id]", text: "Suceso"
    assert_select "label[for=scene_datetime]", text: "Tiempo en el mundo"
    # The blank event option clears the reference and the values are event ids, so
    # neither is translated; only the label is.
    assert_select "select[name='scene[section_id]'] option[value='']", text: "Sin agrupar"
    assert_select "select[name='scene[event_id]'] option[value='']", text: "Ninguno"
    assert_select "select[name='scene[event_id]'] option[value=?]", events(:event_one).id,
      text: events(:event_one).display_string
    assert_select "input[type=submit][value=?]", "Crear escena"
    assert_select "a.btn-link", text: "Cancelar"
    # The closing sentence names the list's own translated controls rather than two
    # English words written into a Spanish frame.
    assert_select "p.form-text", text: /los controles Subir\/Bajar de la lista de escenas/
    assert_select "p.form-text a[href=?]", universe_story_scenes_path(universe_slug: @universe.slug, story_id: @story),
      text: "lista de escenas"
  end

  test "the editor's own tab strip and update button are Spanish" do
    get edit_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene)

    assert_response :success
    # The browser tab names the record being edited; the page keeps the
    # workspace's own title.
    assert_equal "Editar Scene one", rendered_title
    assert_select "h1", text: "Editar escena"
    assert_select ".page-description", text: /Actualiza el título, la descripción breve/
    assert_select "input[type=submit][value=?]", "Actualizar escena"
    assert_select "nav.content-tabs a.active", text: "Detalles de la escena"
  end

  test "a rejected Scene create is explained in Spanish, with its own record type" do
    post universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story), params: {
      scene: { name: "", section_id: sections(:section_alt).id }
    }

    assert_response :unprocessable_content
    # The subject comes from `scenes.errors.subject`, which is the whole phrase the
    # shared sentence needs — article included — so it does not read "este escena".
    assert_select ".alert-danger[role=alert] h2", text: "2 errores impidieron guardar esta escena:"
    # The attribute names come from `activerecord.attributes.scene`, so an error
    # names the field the way the label above it does.
    messages = css_select(".alert-danger[role=alert] li").map { |item| item.text.squish }

    assert_includes messages, "Título no puede estar en blanco"
    assert(messages.any? { |message| message.match?(/Sección debe pertenecer a la misma historia/) },
      "expected the cross-story Section refusal, got: #{messages.inspect}")
  end

  test "the Scene confirmations are written in the chosen language" do
    assert_difference("Scene.count") do
      post universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
        params: { scene: { name: "Escena nueva" } }
    end

    assert_equal "La escena se ha creado correctamente.", flash[:notice]

    created = @story.scenes.find_by!(name: "Escena nueva")
    patch universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: created),
      params: { scene: { description: "Cambiada" } }

    assert_equal "La escena se ha actualizado correctamente.", flash[:notice]

    # A new scene is appended to the end of the sequence, so moving it down would be
    # the boundary no-op; moving it up is the real change.
    patch move_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: created),
      params: { direction: "up" }

    assert_equal "La escena se ha movido.", flash[:notice]

    assert_difference("Scene.count", -1) do
      delete universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: created)
    end

    assert_equal "La escena se ha eliminado correctamente.", flash[:notice]
  end

  test "the move and grouping confirmations are Spanish and name the Section" do
    # Moving the first scene up is a deliberate no-op with its own copy rather
    # than a silent success.
    patch move_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene),
      params: { direction: "up" }

    assert_equal "Esta escena ya está la primera en el orden narrativo.", flash[:alert]

    patch move_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene),
      params: { direction: "down" }

    assert_equal "La escena se ha movido.", flash[:notice]

    patch group_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
      params: { scene_id: @scene.id, section_id: sections(:section_two).id }

    assert_equal "«Scene one» ahora está agrupada bajo Section one / Section two. Su posición narrativa no ha cambiado.",
      flash[:notice]

    patch group_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
      params: { scene_id: @scene.id, section_id: "" }

    assert_equal "«Scene one» ahora está sin agrupar. Su posición narrativa no ha cambiado.", flash[:notice]
  end

  test "the Characters tab, its badges, and its editor are Spanish" do
    get universe_story_scene_scene_characters_url(universe_slug: @universe.slug, story_id: @story, scene_id: @scene)

    assert_response :success
    assert_equal "Personajes en Scene one", rendered_title
    assert_select "h1", text: "Personajes"
    assert_select ".page-eyebrow", text: "Escena: Scene one"
    assert_select ".page-header .badge[aria-label=?]", "2 personajes"
    assert_select ".page-actions a", text: "Detalles de la escena"
    assert_select "button[data-action='modal-form#open']", text: "Añadir personaje"
    assert_select ".modal-title", text: "Añadir personaje"
    # The role is the author's own free text, interpolated into the row's label.
    assert_select ".entity-description", text: "Rol: setting"
    # A blank role is a real state and says so in Spanish.
    assert_select ".entity-description", text: "Rol: No hay rol registrado"
    # The badges say why the character is here: stored, derived, or both.
    assert_select ".badge", text: "Participante"
    assert_select ".badge", text: "Habla en 1 elemento"
    assert_select ".form-text", text: "Habla en Michael teaches the waltz."
    assert_select "label[for=scene_character_character_id]", text: "Personaje"
    assert_select "select[name='scene_character[character_id]'] option[value='']", text: "Elige un personaje"
    assert_select "label[for=scene_character_role]", text: "Rol"
    assert_select "input[type=submit][value=?]", "Guardar personaje"
  end

  test "the participation row menu is Spanish and states what removal keeps" do
    get universe_story_scene_scene_characters_url(universe_slug: @universe.slug, story_id: @story, scene_id: @scene)

    assert_response :success
    assert_select ".row-actions button[aria-label=?]",
      "Acciones para Character one en Scene one"
    # The control withdraws a link rather than deleting a record, so it says
    # "Remove" rather than the shared row action's "Delete".
    assert_select ".row-actions button[data-action='modal-form#destroy']", text: "Quitar"
    assert_select ".row-actions button[data-modal-form-confirm=?]",
      "¿Quitar a Character one de Scene one? El personaje sigue en el universo, y quien hable en un " \
      "diálogo no se ve afectado."
    assert_select ".row-actions button[data-modal-form-title=?]", "Editar rol"
  end

  test "the Items tab and its editor are Spanish" do
    get universe_story_scene_scene_items_url(universe_slug: @universe.slug, story_id: @story, scene_id: @scene)

    assert_response :success
    assert_equal "Objetos en Scene one", rendered_title
    assert_select "h1", text: "Objetos"
    assert_select ".page-eyebrow", text: "Escena: Scene one"
    assert_select "button[data-action='modal-form#open']", text: "Añadir objeto"
    assert_select ".badge", text: "Enlazado"
    assert_select ".entity-description", text: "Rol: carries"
    assert_select ".entity-description", text: "Rol: No hay rol registrado"
    assert_select "label[for=scene_item_item_id]", text: "Objeto"
    assert_select "select[name='scene_item[item_id]'] option[value='']", text: "Elige un objeto"
    assert_select "input[type=submit][value=?]", "Guardar objeto"
    assert_select ".row-actions button[data-modal-form-confirm=?]",
      "¿Quitar Item one de Scene one? El objeto sigue en el universo y en todas las demás escenas."
  end

  test "the Locations tab and its editor are Spanish" do
    get universe_story_scene_scene_locations_url(universe_slug: @universe.slug, story_id: @story, scene_id: @scene)

    assert_response :success
    assert_equal "Lugares en Scene one", rendered_title
    assert_select "h1", text: "Lugares"
    assert_select ".page-eyebrow", text: "Escena: Scene one"
    assert_select "button[data-action='modal-form#open']", text: "Añadir lugar"
    assert_select ".badge", text: "Enlazado"
    assert_select ".entity-description", text: "Rol: setting"
    assert_select "label[for=scene_location_location_id]", text: "Lugar"
    assert_select "select[name='scene_location[location_id]'] option[value='']", text: "Elige un lugar"
    assert_select "input[type=submit][value=?]", "Guardar lugar"
    assert_select ".row-actions button[data-modal-form-confirm=?]",
      "¿Quitar Location one de Scene one? El lugar sigue en el universo, con sus lugares anidados, y " \
      "en todas las demás escenas."
  end

  test "an empty presence tab explains itself in Spanish" do
    get universe_story_scene_scene_items_url(universe_slug: @universe.slug, story_id: @story,
      scene_id: scenes(:scene_two))

    assert_response :success
    assert_select ".empty-title", text: "Todavía no hay objetos en esta escena"
    assert_select ".empty-description", text: /Añade un objeto para registrar que aparece aquí/
  end

  test "the Sections workspace's ungrouped block is Spanish" do
    get universe_story_sections_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_select ".scene-grouping h2", text: "Escenas sin agrupar"
    # The paragraph is one sentence with a link in it, and the count of already
    # grouped scenes is a `count:`-resolved phrase inside it.
    assert_select ".scene-grouping p", text: /Las otras 2 escenas de Story One están agrupadas/
    assert_select ".scene-grouping p a[href=?]",
      universe_story_scenes_path(universe_slug: @universe.slug, story_id: @story), text: "lista de escenas"
    assert_select ".scene-grouping .badge", text: "1 escena sin agrupar"
    assert_select ".scene-grouping .badge[aria-label=?]", "Posición narrativa 3"
    assert_select "label[for=scene_grouping_scene_id]", text: "Escena sin agrupar"
    assert_select "label[for=scene_grouping_section_id]", text: "Mover a"
    assert_select "input[type=submit][value=?]", "Mover escena"
  end

  test "the Section Tag taxonomy and its record page are Spanish" do
    get universe_story_section_tags_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    # The taxonomy workspace and this page read the same `tags.types.section.*`
    # copy, so the title is one string in both places.
    assert_equal "Etiquetas de secciones", rendered_title
    assert_select "h1", text: "Etiquetas de secciones"
    assert_select ".page-eyebrow", text: "Historia: Story One"
    assert_select ".page-description", text: /Define etiquetas como libro, capítulo, acto o episodio/
    assert_select ".page-actions button", text: "Añadir etiqueta de sección"

    section_tag = section_tags(:section_tag_one)
    get universe_story_section_tag_url(universe_slug: @universe.slug, story_id: @story, id: section_tag)

    assert_response :success
    assert_equal section_tag.name, rendered_title
    assert_select ".page-eyebrow", text: "Historia: Story One"
    assert_select ".surface-card .page-eyebrow", text: "Etiqueta de sección"
    assert_select "dt", text: "Ámbito"
    assert_select ".detail-facts dd", text: /Las etiquetas son etiquetas opcionales y pertenecen a esta historia/
    assert_select "h2", text: "Secciones con esta etiqueta"
    assert_select ".page-actions a", text: "Todas las etiquetas de secciones"
    assert_select ".form-check-label", text: "Incluir registros de las etiquetas hijas"
  end

  test "an unused Section Tag says the empty sentence with a singular noun" do
    unused = SectionTag.create!(story: @story, name: "Sin usar", taggable: true)

    get universe_story_section_tag_url(universe_slug: @universe.slug, story_id: @story, id: unused)

    assert_response :success
    # The shared empty sentence takes one noun, so the record type is resolved at
    # `count: 1` rather than in the plural.
    assert_select ".empty-title", text: "Ninguna sección lleva esta etiqueta"
    assert_select ".empty-description", text: /las secciones pueden quedarse sin etiquetar/
  end

  test "the Scene Tag taxonomy, its record page, and its confirmation are Spanish" do
    get universe_story_scene_tags_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_equal "Etiquetas de escenas", rendered_title
    assert_select "h1", text: "Etiquetas de escenas"
    assert_select ".page-description", text: /Define etiquetas opcionales para las escenas de esta historia/
    assert_select ".page-actions button", text: "Añadir etiqueta de escena"
    # The tree sends its confirmation to the browser as a per-node attribute, so
    # that is where the copy is read. The tag's own name is data.
    assert_select ".taxonomy-node[data-confirm-message=?]",
      "¿Eliminar «Scene tag one»? Sus etiquetas hijas y sus asignaciones se eliminarán. Las escenas se conservarán."

    scene_tag = scene_tags(:scene_tag_one)
    get universe_story_scene_tag_url(universe_slug: @universe.slug, story_id: @story, id: scene_tag)

    assert_response :success
    assert_select ".surface-card .page-eyebrow", text: "Etiqueta de escena"
    assert_select "h2", text: "Escenas con esta etiqueta"
    assert_select ".page-actions a", text: "Todas las etiquetas de escenas"
    assert_select ".detail-section .badge[aria-label=?]", "1 escena"
  end

  test "an unused Scene Tag says the empty sentence with a singular noun" do
    unused = SceneTag.create!(story: @story, name: "Sin usar", taggable: true)

    get universe_story_scene_tag_url(universe_slug: @universe.slug, story_id: @story, id: unused)

    assert_response :success
    assert_select ".empty-title", text: "Ninguna escena lleva esta etiqueta"
    assert_select ".empty-description", text: /las escenas pueden quedarse sin etiquetar/
  end

  test "the Appears in scenes section on a universe record is Spanish" do
    get universe_story_path(universe_slug: @universe.slug, id: @story)

    assert_response :success

    get universe_character_url(universe_slug: @universe.slug, id: characters(:character_one))

    assert_response :success
    # The Story's name is the author's own record name, so it is interpolated into
    # the translated heading.
    assert_select ".detail-section h2", text: "Aparece en escenas de Story One"
    assert_select ".detail-section .badge[aria-label=?]", "Posición narrativa 1 de 3"
    assert_select ".detail-section .badge", text: "Enlazado"
    assert_select ".detail-section .badge", text: "Habla en 1 elemento"
    assert_select ".detail-section .entity-description", text: "Rol: setting"
    assert_select ".detail-section .form-text", text: "Habla en Michael teaches the waltz."
  end

  test "an event's appearances say so in Spanish without a role line" do
    get universe_story_path(universe_slug: @universe.slug, id: @story)

    get universe_event_url(universe_slug: @universe.slug, id: events(:event_one))

    assert_response :success
    assert_select ".detail-section .badge", text: "Representado"
    # An Event reference is not a presence link, so it never shows a role line.
    assert_select ".detail-section .entity-description", count: 0
  end

  test "without a current Story the appearances section asks for one, in Spanish" do
    get universe_item_url(universe_slug: @universe.slug, id: items(:item_one))

    assert_response :success
    assert_select ".detail-section h2", text: "Aparece en escenas"
    assert_select ".empty-title", text: "Selecciona una historia para ver sus escenas"
    assert_select ".empty-state a[href=?]", universe_stories_path(universe_slug: @universe.slug),
      text: "Todas las historias"
  end

  private
    def rendered_title
      Nokogiri::HTML(response.body).at_css("title").text
    end

    # The Element kind descriptions the browser receives, read out of the DOM
    # rather than by calling the helper, because the contract is what the browser
    # gets rather than what Ruby returns.
    def scene_element_kind_descriptions
      element = Nokogiri::HTML(response.body).at_css("[data-scene-element-form-descriptions-value]")

      JSON.parse(element["data-scene-element-form-descriptions-value"])
    end
end
