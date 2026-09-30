require "application_system_test_case"

# A Spanish page, in a real browser, on a page whose chrome is built in
# JavaScript.
#
# The request tests prove the *server* answers in Spanish, and they can only read
# what the server rendered. Everything in this file is the other half: the words
# a Stimulus controller typed into the DOM after the page loaded. Before this
# slice that was a known gap — the four editors carried English copy of their
# own, so a Spanish page had translated chrome and an English **Use this photo**
# button — and no request test could have found it, because the sentence was
# never in the response.
#
# It is asserted through the DOM rather than by reading the blob, because the
# point is what a reader actually sees. A blob assertion would pass while a
# controller ignored it, which is precisely the bug class this slice closed.
#
# Author data is English throughout, so nothing here asserts on a record's own
# words — every assertion is on a word the application owns.
class SpanishClientStringsTest < ApplicationSystemTestCase
  test "the photo editor a Spanish page builds is Spanish" do
    switch_to_spanish

    visit universe_characters_path(universe_slug: @universe.slug)
    click_button "Añadir personaje"

    # The control builds its whole widget on connect, so the chooser's own words
    # are on screen before any file is chosen.
    within ".modal.show .photo-field" do
      assert_selector "label", text: "Foto"
      assert_selector ".form-text", text: /Una foto siempre es cuadrada/
    end

    attach_photo
    assert_selector ".photo-crop", wait: 5

    # The cropper's own controls, all of which exist only because the controller
    # created them a moment ago. The accessible names are asserted as attributes
    # rather than as text, because that is where they live — a label a screen
    # reader reads and a sighted reader never sees is still chrome, and the whole
    # point is that it is translated.
    within ".modal.show" do
      assert_equal "Área de recorte de la foto. Las flechas mueven la imagen, y más y menos la amplían.",
        find(".photo-crop-stage")["aria-label"]
      assert_equal "Ampliar la foto", find(".photo-crop-controls input[type='range']")["aria-label"]
      assert_equal "Mover la foto dentro del cuadrado",
        find(".photo-crop-nudge")["aria-label"]
      [ "Mover a la izquierda", "Mover arriba", "Mover abajo", "Mover a la derecha" ].each do |label|
        assert(within(".photo-crop-nudge") { all("button") }.any? { |button| button["aria-label"] == label },
          "expected a move button labelled #{label.inspect}")
      end
      assert_selector ".photo-crop-controls label", text: "Ampliar"
      # The cropper's Cancel and the modal's own footer Cancel are the same word,
      # from the same key, so both are Spanish.
      assert_selector ".photo-crop-controls button", text: "Cancelar"
      assert_selector ".modal-footer button", text: "Cancelar"
      assert_selector ".photo-crop-controls button", text: "Usar esta foto"
    end

    within ".modal.show" do
      click_button "Usar esta foto"
    end
    assert_text "Foto elegida"
  end

  test "the taxonomy editor a Spanish page builds is Spanish" do
    switch_to_spanish
    tag = character_tags(:character_tag_two)

    visit universe_character_tags_path(universe_slug: @universe.slug)

    # The inline create row, built by the controller rather than rendered. Its
    # input's accessible name is an attribute, not visible text.
    click_button "Añadir etiqueta de personaje"
    within ".taxonomy-new" do
      assert_equal "Nombre nuevo", find("input[name='name']")["aria-label"]
      assert_selector "button", text: "Guardar"
      assert_selector "button", text: "Cancelar"
    end

    # The details editor, which the controller builds in `document.body` and so
    # is not in the response at all.
    within "li[data-node-id='#{tag.id}'] > .taxonomy-row" do
      find("button[aria-expanded='false']").click
      click_button "Editar"
    end
    within ".modal.show" do
      assert_selector ".modal-title", text: "Editar #{tag.name}"
      assert_selector ".modal-footer button", text: "Cancelar"
      assert_selector ".modal-footer button", text: "Guardar los cambios"
    end
  end

  test "the flat-list editor reports a rejected save in Spanish" do
    switch_to_spanish
    character = characters(:character_one)

    visit universe_characters_path(universe_slug: @universe.slug)

    within first(".entity-row", text: character.name) do
      find("button[aria-expanded='false']").click
      click_button "Editar"
    end
    within ".modal.show" do
      # A blank name is refused by the server, so the summary, its heading, and
      # the field message beside the input are all built by the controller rather
      # than rendered by a template. The heading is the shared `fix_and_retry`
      # sentence — the same key the taxonomy editor uses.
      find("input[name='character[name]']").set(" ")
      click_button "Guardar personaje"
    end

    assert_selector ".modal-errors", text: "No se pudo guardar el cambio", wait: 10
    # The field message is the server's own Spanish `errors.format` tail, read
    # next to the label the editor already printed.
    assert_selector ".invalid-feedback", text: "no puede estar en blanco"
  end

  private
    def setup
      super
      @universe = universes(:universe_one)
    end

    def switch_to_spanish
      sign_in_via_form(users(:user_one))
      visit settings_path(section: "language")
      choose "Español"
      click_button "Save language"
      # The language form opts out of Turbo, so the whole document has already
      # been replaced by the time the assertion sees the new one.
      assert_selector "html[lang='es']"
    end

    def attach_photo
      path = Rails.root.join("tmp/photos/spanish.png")
      unless path.exist?
        FileUtils.mkdir_p(path.dirname)
        built = system("convert", "-size", "600x400", "gradient:#7c3aed-#2563eb", path.to_s,
          out: File::NULL, err: File::NULL)
        raise "could not build the test image" unless built
      end

      within ".modal.show" do
        find(".photo-field input[type=file]").set(path.to_s)
      end
    end
end
