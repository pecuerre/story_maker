require "test_helper"

# The Universe Bible workspaces rendered in Spanish: Characters, Locations,
# Events, Items, Relations, Ownerships, and the six universe-level tag
# taxonomies with their record pages.
#
# These are request tests rather than assertions on `I18n.locale`, for the reason
# `WorkspaceLocaleTest` gives: the contract a reader depends on is the *rendered
# page*, and a locale that is set but not threaded into a view, a helper, or a
# controller flash is invisible to a locale assertion.
#
# They are not a check that a Spanish page contains no English at all. Author data
# — a character name, a tag name, an `Event#display_string` — is never translated,
# the four Stimulus controllers still hardcode their own copy, and three
# `errors.add` messages in shared model concerns are named in the slice that owns
# them. What is asserted is that each workspace's own chrome came from the
# Spanish keys, and that the values that travel in a form field, an option, or a
# URL did *not* get translated along with their labels.
class UniverseBibleLocaleTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    sign_in_as(users(:user_one))
    patch settings_url, params: { locale: "es" }
  end

  test "the Characters list, its empty state, and its editor are Spanish" do
    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    assert_equal "Personajes", rendered_title
    assert_select "h1", text: "Personajes"
    assert_select ".page-eyebrow", text: "Biblia del universo"
    assert_select ".page-description", text: /Personas y seres/
    # The count is resolved with a `count:`, so the plural comes from the locale.
    assert_select ".page-header .badge[aria-label=?]", "3 personajes"
    assert_select "nav.content-tabs a.active", text: "Personajes"
    assert_select "nav.content-tabs a", text: "Relaciones"
    assert_select "button.btn-primary[data-action='modal-form#open']", text: "Añadir personaje"
    assert_select "h2.modal-title", text: "Nuevo personaje"
    assert_select "label[for=character_name]", text: "Nombre"
    assert_select "label[for=character_description]", text: "Descripción"
    assert_select "label[for=character_character_tag_ids]", text: "Etiquetas de personajes"
    assert_select "input[type=submit][value=?]", "Guardar personaje"
    assert_select ".modal-footer button[data-bs-dismiss=modal]", text: "Cancelar"
    assert_select ".modal-header button.btn-close[aria-label=?]", "Cerrar"
    # Author data is never translated: the character's own name still reads as its
    # author typed it.
    assert_select ".entity-title", text: "Character one"
  end

  test "an empty Characters list tells a writer and a read-only member different things" do
    @universe.characters.find_each(&:soft_delete)

    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".empty-title", text: "Todavía no hay personajes"
    assert_select ".empty-description", text: /Añade el primero para empezar/

    sign_out
    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".empty-description", text: /Los personajes pertenecen al universo/
  end

  test "the row menu is Spanish and names the record type it edits" do
    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    # `label` titles the edit entry, so it is the record type's own name — read
    # from the root record-type noun, not from a humanized class name.
    assert_select ".row-actions button[data-modal-form-method=patch][data-modal-form-title=?]",
      "Editar personaje"
    assert_select ".row-actions button[data-action='modal-form#destroy']", text: "Eliminar"
    assert_select ".row-actions button[data-action='modal-form#destroy'][data-modal-form-confirm=?]",
      "¿Eliminar «Character one»? Sus personajes descendientes, relaciones, propiedades, " \
      "asignaciones de etiquetas y enlaces a escenas se eliminarán de forma permanente. Las escenas " \
      "y otros registros del universo permanecerán."
  end

  test "a Character's own page states its facts in Spanish" do
    character = characters(:character_one)
    character.update_column(:description, nil)

    get universe_character_url(universe_slug: @universe.slug, id: character)

    assert_response :success
    assert_equal character.name, rendered_title
    assert_select ".page-eyebrow", text: "Personaje"
    assert_select "dt", text: "Universo"
    assert_select "dt", text: "Etiquetas de personajes"
    assert_select "dt", text: "Descripción"
    assert_select ".detail-facts dd", text: "Todavía no hay descripción."
    assert_select ".page-actions a", text: "Todos los personajes"
  end

  test "a Character with no tags says tags are optional, in Spanish" do
    character = characters(:character_one)
    character.character_tags.clear

    get universe_character_url(universe_slug: @universe.slug, id: character)

    assert_response :success
    assert_select ".detail-facts dd", text: /Las etiquetas son opcionales/
  end

  test "the Locations tree, its empty state, and a Location's own page are Spanish" do
    get universe_locations_url(universe_slug: @universe.slug)

    assert_response :success
    assert_equal "Lugares", rendered_title
    assert_select "h1", text: "Lugares"
    assert_select ".page-eyebrow", text: "Biblia del universo"
    assert_select ".page-actions button", text: "Añadir lugar"
    assert_select "nav.content-tabs a.active", text: "Lugares"
    # The tree names its own empty state from the model param, not from a
    # hand-written string, and this workspace has no separate empty title.
    assert_select ".taxonomy-node", 2

    location = locations(:location_one)
    Location.create!(universe: @universe, name: "Hijo", parent: location)

    get universe_location_url(universe_slug: @universe.slug, id: location)

    assert_response :success
    assert_select ".page-eyebrow", text: "Lugar"
    assert_select "dt", text: "Lugar padre"
    assert_select "dt", text: "Lugares hijos"
    # A count and its record type, resolved with a `count:` from the locale, in
    # the same fact row as its own label.
    assert_includes fact_values, [ "Lugares hijos", "1 lugar" ]
    assert_select ".page-actions a", text: "Todos los lugares"
  end

  test "an empty Locations tree names itself and asks for the first record" do
    @universe.locations.find_each(&:soft_delete)

    get universe_locations_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".empty-title", text: "Todavía no hay lugares"
    assert_select ".empty-description", text: /Añade un lugar y luego arrastra las filas/
  end

  test "the Events list, its editor, and the temporal references are Spanish" do
    get universe_events_url(universe_slug: @universe.slug)

    assert_response :success
    assert_equal "Sucesos", rendered_title
    assert_select "h1", text: "Sucesos"
    assert_select "button.btn-primary[data-action='modal-form#open']", text: "Añadir suceso"
    assert_select "h2.modal-title", text: "Nuevo suceso"
    assert_select ".modal-body p.text-body-secondary", text: /Un suceso necesita al menos un título/
    assert_select "label[for=event_title]", text: "Título"
    assert_select "label[for=event_start_datetime]", text: "Fecha/hora de inicio"
    assert_select "label[for=event_end_datetime]", text: "Fecha/hora de fin"
    assert_select "label[for=event_before_event_id]", text: "Ocurre antes"
    assert_select "label[for=event_after_event_id]", text: "Ocurre después"
    assert_select "label[for=event_simultaneous_event_id]", text: "Al mismo tiempo que"
    assert_select "input[type=submit][value=?]", "Guardar suceso"
    # The blank option clears a reference, and the values beside every label are
    # event ids, so neither the blank nor the ids are translated.
    assert_select "select[name='event[before_event_id]'] option[value='']", text: "Ninguno"
    assert_select "select[name='event[before_event_id]'] option[value=?]",
      events(:event_one).id.to_s
  end

  test "an Event's delete confirmation is Spanish and states its consequences" do
    get universe_events_url(universe_slug: @universe.slug)

    assert_response :success
    # The confirmation is interpolated onto a per-row attribute, so it is read
    # from the DOM rather than from a rendered button. The event's own label is
    # data and is interpolated, not translated.
    assert_select ".row-actions button[data-modal-form-confirm=?]",
      "¿Eliminar «The beginning - 2026-09-11 09:00»? Sus sucesos hijos, las asignaciones de etiquetas y " \
      "cualquier referente temporal que quedara sin identificar se eliminarán de forma permanente; las " \
      "demás referencias temporales y los enlaces a escenas se vaciarán. Las escenas permanecerán."
  end

  test "an Event's own page states its facts in Spanish" do
    event = events(:event_one)
    event.update_columns(title: nil, description: nil)

    get universe_event_url(universe_slug: @universe.slug, id: event)

    assert_response :success
    assert_select ".page-eyebrow", text: "Suceso"
    assert_select "dt", text: "Título"
    assert_select "dt", text: "Tiempo en el mundo"
    # `display_string` always answers, so the title fact falls back to the
    # event's own label rather than rendering a blank state.
    assert_select ".detail-facts dd", text: "2026-09-11 09:00"
    assert_select ".detail-facts dd", text: "Todavía no hay descripción."
    assert_select ".page-actions a", text: "Todos los sucesos"
  end

  test "an Event's own refusals are stated in Spanish" do
    get universe_events_url(universe_slug: @universe.slug), params: nil

    assert_response :success

    post universe_events_url(universe_slug: @universe.slug),
      params: { event: { description: "Sin identidad" } },
      as: :json

    assert_response :unprocessable_content
    # The attribute names come from `activerecord.attributes.event`, and the
    # `errors.add` message from `events.errors`, so neither is left English.
    assert_equal [ "debe tener un título, una fecha o una relación con otro suceso" ],
      response.parsed_body["base"]

    other = Event.create!(universe: @universe, title: "Otro")
    patch universe_event_url(universe_slug: @universe.slug, id: events(:event_one)),
      params: { event: { before_event_id: events(:event_one).id } },
      as: :json

    assert_response :unprocessable_content
    assert_equal [ "no puede ser él mismo" ], response.parsed_body["before_event"]

    # A cross-universe reference is refused with the same translated message.
    foreign = Event.create!(universe: universes(:universe_two), title: "Ajeno")
    patch universe_event_url(universe_slug: @universe.slug, id: other),
      params: { event: { after_event_id: foreign.id } },
      as: :json

    assert_response :unprocessable_content
    assert_equal [ "debe pertenecer al universo del suceso" ], response.parsed_body["after_event"]
  end

  test "the Items list and a Item's own page are Spanish" do
    get universe_items_url(universe_slug: @universe.slug)

    assert_response :success
    assert_equal "Objetos", rendered_title
    assert_select "h1", text: "Objetos"
    assert_select "button.btn-primary[data-action='modal-form#open']", text: "Añadir objeto"
    assert_select "label[for=item_item_tag_ids]", text: "Etiquetas de objetos"
    assert_select "input[type=submit][value=?]", "Guardar objeto"
    assert_select "nav.content-tabs a", text: "Propiedades"

    item = items(:item_one)
    get universe_item_url(universe_slug: @universe.slug, id: item)

    assert_response :success
    assert_select ".page-eyebrow", text: "Objeto"
    assert_select "dt", text: "Etiquetas de objetos"
    assert_select ".page-actions a", text: "Todos los objetos"
  end

  test "an Item's delete confirmation is Spanish and states its consequences" do
    item = items(:item_one)

    get universe_items_url(universe_slug: @universe.slug)

    assert_response :success
    # The confirmation is interpolated onto a per-row attribute, so it is read from
    # the DOM rather than from a rendered button. The item's own name is data and
    # is interpolated, not translated.
    assert_select ".row-actions button[data-modal-form-confirm=?]",
      "¿Eliminar «#{item.name}»? Sus objetos descendientes, propiedades, asignaciones de etiquetas " \
      "y enlaces a escenas se eliminarán de forma permanente. Las escenas y otros registros del " \
      "universo permanecerán."
  end

  test "a Location's delete confirmation is Spanish and states its consequences" do
    get universe_locations_url(universe_slug: @universe.slug)

    assert_response :success
    # The tree sends its confirmation to the browser as a per-node attribute rather
    # than as a rendered button, so that is where the copy is read.
    assert_select "li.taxonomy-node[data-confirm-message=?]",
      "¿Eliminar «#{locations(:location_one).name}»? Sus lugares descendientes, asignaciones de " \
      "etiquetas y enlaces a escenas se eliminarán de forma permanente. Las escenas y otros " \
      "registros del universo permanecerán."
  end

  test "an empty Items list names itself in Spanish" do
    @universe.items.find_each(&:soft_delete)

    get universe_items_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".empty-title", text: "Todavía no hay objetos"
    assert_select ".empty-description", text: /Añade el primero para empezar/
  end

  test "the Relations workspace, its editor, and its rejected-create copy are Spanish" do
    relation = Relation.create!(universe: @universe, character1: characters(:character_one),
      character2: characters(:character_two))

    get universe_relations_url(universe_slug: @universe.slug)

    assert_response :success
    assert_equal "Relaciones", rendered_title
    assert_select "h1", text: "Relaciones"
    # Relations is filed under the Characters tab strip, so its eyebrow names
    # that tab rather than the section it lives in.
    assert_select ".page-eyebrow", text: "Personajes"
    assert_select "button.btn-primary[data-action='modal-form#open']", text: "Añadir relación"
    assert_select "nav.content-tabs a.active", text: "Relaciones"
    assert_select "nav.content-tabs a", text: "Personajes"
    assert_select "label[for=relation_character1_id]", text: "Personaje 1"
    assert_select "label[for=relation_character2_id]", text: "Personaje 2"
    assert_select "select[name='relation[character1_id]'] option", text: "Selecciona un personaje"
    assert_select "label[for=relation_from_date]", text: "Desde"
    assert_select "label[for=relation_to_date]", text: "Hasta"
    assert_select "input[type=submit][value=?]", "Guardar relación"
    # A delete is the HTML redirect flow here, so its confirmation is a Turbo
    # attribute rather than a modal one. `button_to` puts it on the button it
    # renders, not on the form around it.
    assert_select "form[action=?] button[data-turbo-confirm=?]",
      universe_relation_path(universe_slug: @universe.slug, id: relation),
      "¿Eliminar Character one and Character two?"
  end

  test "a rejected Relation create is explained in Spanish, with its own record type" do
    post universe_relations_url(universe_slug: @universe.slug), params: {
      relation: { character1_id: characters(:character_one).id, character2_id: "" }
    }

    assert_response :unprocessable_content
    # The subject comes from the workspace's own `errors.subject`, which is the
    # whole phrase the sentence needs — article included — so a plural count still
    # reads "impidieron guardar esta relación" and not "este relación".
    assert_select ".alert-danger[role=alert] h2", text: "2 errores impidieron guardar esta relación:"
    assert_select ".alert-danger[role=alert] li", text: /Personaje 2 no puede estar en blanco/
  end

  test "a Relation's own page states its facts and its empty related section in Spanish" do
    relation = Relation.create!(universe: @universe, character1: characters(:character_one),
      character2: characters(:character_two))
    relation.update_column(:description, nil)

    get universe_relation_url(universe_slug: @universe.slug, id: relation)

    assert_response :success
    assert_select ".page-eyebrow", text: "Relación"
    assert_select "dt", text: "Primer personaje"
    assert_select "dt", text: "Segundo personaje"
    assert_select "dt", text: "Fechas en el mundo"
    assert_select ".detail-facts dd", text: "Todavía no hay descripción."
    assert_select "h2", text: "Información relacionada"
    assert_select ".empty-title", text: "Todavía no hay nada relacionado"
    assert_select ".empty-description", text: /Esta relación es un vínculo entre dos personajes/
    assert_select ".page-actions a", text: "Todas las relaciones"
  end

  test "the Relations confirmations are written in the chosen language" do
    assert_difference("Relation.count") do
      post universe_relations_url(universe_slug: @universe.slug), params: {
        relation: { character1_id: characters(:character_one).id, character2_id: characters(:character_two).id }
      }
    end

    assert_equal "La relación se ha creado.", flash[:notice]

    relation = Relation.order(:id).last
    patch universe_relation_url(universe_slug: @universe.slug, id: relation),
      params: { relation: { description: "Cambiada" } }

    assert_equal "La relación se ha actualizado.", flash[:notice]

    assert_difference("Relation.count", -1) do
      delete universe_relation_url(universe_slug: @universe.slug, id: relation)
    end

    assert_equal "La relación se ha eliminado.", flash[:notice]
  end

  test "the Ownerships workspace, its editor, and its confirmations are Spanish" do
    get universe_ownerships_url(universe_slug: @universe.slug)

    assert_response :success
    assert_equal "Propiedades", rendered_title
    assert_select "h1", text: "Propiedades"
    assert_select ".page-eyebrow", text: "Objetos"
    assert_select "button.btn-primary[data-action='modal-form#open']", text: "Añadir propiedad"
    assert_select "nav.content-tabs a.active", text: "Propiedades"
    assert_select "nav.content-tabs a", text: "Objetos"
    # The form's two labels name the fields, while the record's own facts name
    # what it is in the relationship.
    assert_select "label[for=ownership_item_id]", text: "Objeto"
    assert_select "label[for=ownership_character_id]", text: "Personaje"
    assert_select "select[name='ownership[item_id]'] option", text: "Selecciona un objeto"
    assert_select "label[for=ownership_ownership_tag_ids]", text: "Etiquetas de propiedades"
    assert_select "input[type=submit][value=?]", "Guardar propiedad"

    assert_difference("Ownership.count") do
      post universe_ownerships_url(universe_slug: @universe.slug), params: {
        ownership: { item_id: items(:item_one).id, character_id: characters(:character_one).id }
      }
    end

    assert_equal "La propiedad se ha creado.", flash[:notice]
  end

  test "an Ownership's own page states its facts in Spanish" do
    ownership = Ownership.create!(universe: @universe, item: items(:item_one),
      character: characters(:character_one))

    get universe_ownership_url(universe_slug: @universe.slug, id: ownership)

    assert_response :success
    assert_select ".page-eyebrow", text: "Propiedad"
    assert_select "dt", text: "Objeto"
    assert_select "dt", text: "Propietario"
    assert_select "dt", text: "Fechas en el mundo"
    assert_select "h2", text: "Información relacionada"
    assert_select ".page-actions a", text: "Todas las propiedades"
  end

  test "an empty Ownerships list names itself in Spanish" do
    @universe.ownerships.find_each(&:soft_delete)

    get universe_ownerships_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".empty-title", text: "Todavía no hay propiedades"
    assert_select ".empty-description", text: /Conecta a un personaje con un objeto/
  end

  # The six universe-level taxonomies read the same `tags.types.<type>` copy the
  # taxonomy workspace already uses, so a page and its translations are the same
  # strings in both places rather than two lists that can drift.
  UNIVERSAL_TAXONOMIES = {
    "character" => { title: "Etiquetas de personajes", new_label: "Añadir etiqueta de personaje" },
    "relation" => { title: "Etiquetas de relaciones", new_label: "Añadir etiqueta de relación" },
    "location" => { title: "Etiquetas de lugares", new_label: "Añadir etiqueta de lugar" },
    "event" => { title: "Etiquetas de sucesos", new_label: "Añadir etiqueta de suceso" },
    "item" => { title: "Etiquetas de objetos", new_label: "Añadir etiqueta de objeto" },
    "ownership" => { title: "Etiquetas de propiedades", new_label: "Añadir etiqueta de propiedad" }
  }.freeze

  test "the six universe taxonomies read the same Spanish copy as the taxonomy workspace" do
    UNIVERSAL_TAXONOMIES.each do |type, expected|
      get send(:"universe_#{type}_tags_url", universe_slug: @universe.slug)

      assert_response :success, "#{type} tags index"
      assert_equal expected[:title], rendered_title, "#{type} tags document title"
      assert_select "h1", text: expected[:title]
      assert_select ".page-eyebrow", text: "Biblia del universo"
      assert_select ".page-actions button", text: expected[:new_label]
      # The strip offers both scopes, and the universe scope is the active one.
      assert_select ".tag-scope-tabs a.active", text: "Etiquetas del universo"
      assert_select ".tag-taxonomy-tabs a.active", text: expected[:title]
    end
  end

  test "the serialized modal field descriptors are the translated ones" do
    get universe_character_tags_url(universe_slug: @universe.slug)

    assert_response :success
    # The descriptors are serialized into the tree's own data attribute and
    # printed by a modal the browser builds from it, so the labels have to cross
    # the boundary already translated. `label_key` is how each one is found and is
    # not part of the contract, so it must not travel.
    descriptors = taxonomy_modal_fields

    assert_equal %w[name description bgcolor fgcolor parent_id taggable photo show_in_menu],
      descriptors.map { |field| field["name"] }
    assert_equal [ "Nombre", "Descripción", "Color de fondo", "Color de texto", "Padre",
                   "Etiquetable", "Foto", "Mostrar en el menú" ],
      descriptors.map { |field| field["label"] }
    assert_equal [ nil, nil, nil, nil, nil, nil, nil, nil ],
      descriptors.map { |field| field["label_key"] }

    # The parent selector's blank option is chrome too, and its value is the empty
    # string the form stores.
    parent = descriptors.find { |field| field["name"] == "parent_id" }

    assert_equal [ "", "(Sin padre)" ], parent.fetch("options").first
  end

  test "the Relation tag editor's own extra fields are translated" do
    get universe_relation_tags_url(universe_slug: @universe.slug)

    assert_response :success
    # `symmetric` and `inverse` are the Relation taxonomy's own two fields, and
    # `inverse` stays required unless `symmetric` is ticked — a contract the
    # browser reads, so it is asserted alongside the label.
    descriptors = taxonomy_modal_fields

    assert_equal [ "Simétrica", "Inversa" ],
      descriptors.select { |field| %w[symmetric inverse].include?(field["name"]) }.map { |field| field["label"] }
    assert_equal({ "field" => "symmetric", "value" => true },
      descriptors.find { |field| field["name"] == "inverse" }.fetch("required_unless"))
  end

  test "a taxonomy's own record page states its facts in Spanish" do
    tag = character_tags(:character_tag_one)
    tag.update_column(:description, nil)

    get universe_character_tag_url(universe_slug: @universe.slug, id: tag)

    assert_response :success
    assert_equal tag.name, rendered_title
    # The eyebrow names the right sidebar's section, not the taxonomy, and the
    # record's own label is the singular form of the taxonomy's name. They are
    # both `.page-eyebrow`, so each is asserted where it is rendered.
    assert_select ".page-header .page-eyebrow", text: "Configuración · Etiquetas"
    assert_select ".surface-card .page-eyebrow", text: "Etiqueta de personaje"
    assert_select "dt", text: "Ámbito"
    assert_select "dt", text: "Descripción"
    assert_select "dt", text: "Color"
    assert_select ".detail-facts dd", text: "Todavía no hay descripción."
    # The colour is NOT NULL with a default, so this fact is never blank.
    assert_includes fact_values, [ "Color", tag.bgcolor ]
    assert_select "h2", text: "Personajes con esta etiqueta"
    assert_select ".page-actions a", text: "Todas las etiquetas de personajes"
  end

  test "an unused taxonomy explains itself in Spanish" do
    tag = CharacterTag.create!(universe: @universe, name: "Sin usar", taggable: true)

    get universe_character_tag_url(universe_slug: @universe.slug, id: tag)

    assert_response :success
    # The empty title is the shared sentence with the record type in its plural,
    # so it reads "Ningún personaje…" rather than the singular.
    assert_select ".empty-title", text: "Ningún personaje lleva esta etiqueta"
    assert_select ".empty-description", text: /los personajes pueden quedarse sin etiquetar/
  end

  test "a grouping tag lists one section per child tag, in Spanish" do
    parent = character_tags(:character_tag_two)
    child = CharacterTag.create!(universe: @universe, name: "Hija", parent: parent)

    get universe_character_tag_url(universe_slug: @universe.slug, id: parent, include_descendants: "1")

    assert_response :success
    # A grouping tag has no assignable records of its own, so it lists one section
    # per child tag. A tag's own name titles that section — it is data, and it is
    # never translated — while the section's empty state and its count are chrome.
    assert_select ".detail-section h2", text: child.name
    assert_select ".detail-section .empty-title", text: "Ningún personaje lleva esta etiqueta"
    assert_select ".detail-section .empty-description", text: /Todavía no se usa esta etiqueta hija/
    assert_select ".detail-section .badge[aria-label=?]", "0 personajes"
  end

  test "a grouping tag with no children says so, in Spanish" do
    parent = character_tags(:character_tag_two)

    get universe_character_tag_url(universe_slug: @universe.slug, id: parent)
    assert_response :success
    assert_select ".empty-title", text: "No hay etiquetas hijas"
    assert_select ".empty-description", text: /Esta etiqueta de grupo todavía no tiene etiquetas hijas/
  end

  test "a taggable tag's descendants toggle is Spanish" do
    tag = character_tags(:character_tag_one)

    get universe_character_tag_url(universe_slug: @universe.slug, id: tag)

    assert_response :success
    assert_select ".form-check-label", text: "Incluir registros de las etiquetas hijas"
  end

  test "a pinned tag's details page keeps the workspace tab strip, in Spanish" do
    tag = character_tags(:character_tag_one)
    tag.update!(show_in_menu: true)

    get universe_character_tag_url(universe_slug: @universe.slug, id: tag, from: "workspace")

    assert_response :success
    # The strip's own accessible name is built from the record type's name, not
    # from a humanized class name, and it names the tab this record belongs to.
    assert_select "nav.content-tabs[aria-label=?]", "Espacio de trabajo de personaje"
    assert_select "nav.content-tabs a.active", text: tag.name
    assert_select "nav.content-tabs a", text: "Relaciones"
  end

  private
    def rendered_title
      Nokogiri::HTML(response.body).at_css("title").text
    end

    # The identity block's [label, value] pairs, so an assertion can tie a value
    # to the label it belongs to. `assert_select` cannot pair the two — `:has()`
    # with `text-is` is not available in this Nokogiri build — and a bare `dd`
    # assertion would match the first row whatever it is.
    def fact_values
      Nokogiri::HTML(response.body).css(".detail-fact").map do |fact|
        [ fact.at_css("dt").text.strip, fact.at_css("dd").text.strip ]
      end
    end

    # The field descriptors the taxonomy tree's editor is built from, read out of
    # the DOM rather than by calling the helper, because the contract is what the
    # browser receives rather than what Ruby returns.
    def taxonomy_modal_fields
      raw = Nokogiri::HTML(response.body)
        .at_css("[data-taxonomy-tree-modal-fields-value]")
        .attribute("value") || Nokogiri::HTML(response.body)
          .at_css("[data-taxonomy-tree-modal-fields-value]")["data-taxonomy-tree-modal-fields-value"]

      JSON.parse(raw)
    end
end
