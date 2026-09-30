require "test_helper"

# A Spanish page must not contain English chrome.
#
# The other locale request tests assert that particular strings *are* Spanish.
# That catches a key that was never translated and nothing else: a page can be
# correct about every string it was asked about and still print an English
# sentence beside them — from a JavaScript-built modal, a serialized descriptor,
# or a copy the template inlines. Those are the cases no positive assertion finds,
# because the test would have to already know which string to look for.
#
# So this asserts the negative instead, and it draws the forbidden set from the
# locale files rather than from a list written here: every English value this
# application defines. A value that reaches a Spanish page has then reached it by
# bypassing a key, and the test names the value so the offending key is findable.
#
# What it deliberately does **not** claim to catch, and why:
#
#   - **Author data.** A record's name, a universe's name, a tag's name is the
#     author's own words and is never translated. The fixtures are English, so
#     this test would fail constantly if it could not tell an author's "Dark"
#     from a chrome "Delete". It excludes the values a page can legitimately
#     contain as data.
#   - **A search result row's title.** A search document stores its label in the
#     default locale, so one index serves every reader — a deliberate trade
#     recorded at `docs/features/search.md#a-result-row-shows-the-stored-document-title`.
#   - **A single word.** "Photo", "Zoom", and "Cancel" are short enough that an
#     author's own data can contain one by coincidence, and a substring match on
#     a two-letter word is noise. Only values with real word content are checked,
#     which is where an untranslated sentence actually lives.
class SpanishChromeTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
    sign_in_as(users(:user_one))
    patch settings_url, params: { locale: "es" }
  end

  # Every English string value the application defines, for the keys that own
  # chrome. Read from the locale file rather than repeated, so this cannot go
  # stale as copy is added.
  def english_chrome
    @english_chrome ||= begin
      values = load_locale("en").fetch("en").flat_map { |_namespace, subtree| leaves(subtree) }
      values.select { |value| prose?(value) }.uniq
    end
  end

  test "every page a client-side string can reach carries no untranslated English chrome" do
    # The four surfaces that used to hold English: a taxonomy workspace (the tree
    # and its editor), a flat list (the JSON modal and the photo editor), a scene
    # workspace, and the search page the top-bar box shares a form with.
    pages = [
      [ "the characters list", universe_characters_url(universe_slug: @universe.slug) ],
      [ "a taxonomy workspace", universe_character_tags_url(universe_slug: @universe.slug) ],
      [ "the locations tree", universe_locations_url(universe_slug: @universe.slug) ],
      [ "a scene list", universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id) ],
      [ "the settings page", settings_path ]
    ]

    pages.each do |name, path|
      get path
      assert_response :success, "#{name} did not render"

      assert_no_english_chrome(name)
    end
  end

  # The pages above all render, so they never reach a validation message. That
  # left a whole class of English invisible to this file: a model that answered
  # a rejected save with a literal `errors.add` sentence rather than a key. The
  # reader saw a Spanish page with one English line in it, and every test here
  # passed, because a message that never appears on a successful page is not a
  # value this file searches a body for.
  #
  # So the failing request is the one under test. Each case below is a real
  # mutation that the models above reject, and each is asserted twice: that the
  # Spanish sentence is the one that came back, and that the answer carries no
  # English. The first catches a key that fell back to `en.yml`; the second
  # catches a literal that is not a key at all.
  test "a rejected save answers in Spanish rather than in an English message" do
    # `HasColor`'s format validation, which is the message that used to render as
    # "Color de fondo must be a hex color like #d3d3d3".
    post universe_character_tags_url(universe_slug: @universe.slug),
      params: { character_tag: { name: "Spanish probe", scope: "universe", bgcolor: "not-a-color" } },
      as: :json
    assert_response :unprocessable_content
    assert_equal [ spanish("shared.errors.color.must_be_hex") ], response.parsed_body["bgcolor"]
    assert_no_english_chrome("a rejected taxonomy save")

    # A presence link, whose uniqueness message reaches the Scene's own tab. The
    # Scene comes from the URL, so the payload carries only the link's own fields.
    post universe_story_scene_scene_characters_path(universe_slug: @universe.slug,
      story_id: @story.id, scene_id: @scene.id),
      params: { scene_character: { character_id: characters(:character_one).id } },
      as: :json
    assert_response :unprocessable_content
    assert_equal [ spanish("scenes.participation_errors.already_in_scene") ], response.parsed_body["character_id"]
    assert_no_english_chrome("a rejected presence link")

    # A record-level message, which the browser wraps in a sentence about the
    # record rather than in a field label.
    post universe_story_scene_scene_elements_path(universe_slug: @universe.slug,
      story_id: @story.id, scene_id: @scene.id),
      params: { scene_element: { kind: "dialogue", name: "Spanish probe" } },
      as: :json
    assert_response :unprocessable_content
    assert_equal [ spanish("scenes.element_errors.speakers_required") ], response.parsed_body["character_ids"]
    assert_no_english_chrome("a rejected element save")
  end

  # The server-rendered half of the same rule. A workspace that re-renders its
  # form after a rejected submission prints the model's own messages through
  # `shared/_error_summary`, which is the path a literal sentence takes when the
  # mutation is not a JSON one — and the reason the Relations and Ownerships
  # messages needed translating as carefully as the modal's.
  test "a rejected save renders its summary in Spanish" do
    foreign = universes(:universe_two).characters.create!(name: "Foreign character")

    post universe_relations_path(universe_slug: @universe.slug),
      params: { relation: { name: "Spanish probe", character1_id: foreign.id } }

    assert_response :unprocessable_content

    body = Nokogiri::HTML(response.body).text
    assert_includes body, spanish("relations.errors.must_belong_to_universe")
    assert_no_english_chrome("a rejected relation save")
  end


  test "the client-string blob a Spanish page ships is the Spanish one" do
    get universe_characters_url(universe_slug: @universe.slug)
    assert_response :success

    blob = JSON.parse(Nokogiri::HTML(response.body).at_css("#client-strings").text)

    assert_equal "es", blob["locale"]
    # The blob is the whole client-side surface, so if it is Spanish then every
    # controller on the page is Spanish, including the four that build their own
    # DOM and used to hold English of their own.
    assert_equal "Cancelar", blob["shared.form.cancel"]
    assert_equal "Guardar los cambios", blob["shared.taxonomy_tree.save_changes"]
    assert_equal "Ampliar", blob["shared.photo_field.zoom"]
    assert_equal "Guardando…", blob["shared.modal_form.saving"]
    assert_equal "No se pudo contactar con la búsqueda.", blob["searches.bar.unreachable"]
    assert_equal "este suceso", blob["record_subject"]["event"]
  end

  test "a Spanish page ships no English value from the client-string blob" do
    english = JSON.parse(I18n.with_locale(AppLocale::DEFAULT) { ClientStrings.payload })

    I18n.with_locale(:es) do
      get universe_characters_url(universe_slug: @universe.slug)
      assert_response :success

      spanish = JSON.parse(Nokogiri::HTML(response.body).at_css("#client-strings").text)

      # For every key that carries prose, the value the Spanish page was given
      # must be the Spanish one and not the English one. A key that arrived
      # untranslated is exactly this test failing, and it names the key so the
      # offending entry is findable.
      #
      # `record_subject` is skipped: it is a map of record types, not a string,
      # and its Spanish phrases were asserted directly above.
      leaked = english.filter_map do |key, value|
        next if key == "record_subject"
        next unless [ value, *Array(value.is_a?(Hash) ? value.values : []) ].any? { |candidate| prose?(candidate) }
        next if spanish[key] != value

        key
      end

      assert_empty leaked, "keys shipped to a Spanish page in English: #{leaked.join(', ')}"
    end
  end

  private
    # The reader's answer, not the test process's. `setup` switched the *request*
    # to Spanish through a cookie, and the process itself is still in the default
    # locale, so an expectation has to ask for the Spanish value explicitly or it
    # would compare the body against the English it is supposed not to contain.
    def spanish(key)
      I18n.t(key, locale: :es)
    end

    def assert_no_english_chrome(name)
      body = Nokogiri::HTML(response.body).text

      # Author data is never translated, and the fixtures are English, so a
      # fixture whose own words happen to *contain* a chrome value is a
      # coincidence rather than a bug — a tag named "Character tag one" contains
      # the chrome value "Character tag". The exclusion is therefore on the
      # author string, not on the chrome value: a chrome value found inside a
      # fixture's own words is not a finding, and the fixture words are read from
      # the fixtures so a renamed fixture stays honest.
      offenders = english_chrome.reject do |value|
        fixture_strings.any? { |author_string| author_string.include?(value) }
      end.select { |value| body.include?(value) }

      assert_empty offenders,
        "#{name} printed untranslated English chrome: #{offenders.first(5).inspect}"
    end

    # A value that could only be chrome: it reads as a sentence, in words, with
    # nothing left to interpolate.
    #
    # Four things are excluded, each because a Spanish page may legitimately
    # contain it and the match would be noise rather than a finding:
    #
    #   - **A frame.** `"%{label} %{message}"` is a shape two already-translated
    #     words are placed into. It appears in the client blob by design, and it
    #     has no English in it to find.
    #   - **A single short word.** The fixtures are English and an author's own
    #     data contains "Photo" and "Delete"; a substring match on a short word
    #     finds those, not a bug.
    #   - **A proper noun.** The application's own name is not translated in any
    #     locale, because it is a name.
    #   - **A code identifier.** `Set MEILISEARCH_URL` and `bin/rails
    #     search:reindex` are an environment variable and a command, which are
    #     the same in every language by definition.
    def prose?(value)
      return false unless value.is_a?(String)
      return false if value.include?("%{") || value.include?("%1")
      return false if value.split(/\s+/).size < 2
      return false unless value.match?(/[A-Za-z]{3,}/)
      return false if value.match?(/[A-Z]{3,}|\b[a-z_]+\.[a-z_]+\b|\b[A-Z_]{3,}\b|https?:|[A-Z_]+_[A-Z_]+/)
      return false if value == "Universe Maker"

      true
    end

    # The strings a page may legitimately show as author data, read from the
    # fixtures rather than listed, so a fixture renamed in a test stays honest.
    def fixture_strings
      @fixture_strings ||= begin
        strings = []
        [ Character, Location, Event, Item, Universe, Story, Section, Scene,
          CharacterTag, LocationTag, EventTag, ItemTag, SectionTag, SceneTag,
          RelationTag, OwnershipTag ].each do |model|
          model.find_each { |record| strings.concat([ record.try(:name), record.try(:title), record.try(:description) ].compact.map(&:to_s)) }
        end
        strings.concat([ CharacterTag.pluck(:name), LocationTag.pluck(:name), Universe.pluck(:name), Story.pluck(:name) ].flatten)
        strings.select { |value| value.length >= 12 }.uniq
      end
    end

    def leaves(node)
      case node
      when Hash
        if node.keys.all? { |key| %w[zero one two few many other].include?(key.to_s) }
          node.values
        else
          node.values.flat_map { |value| leaves(value) }
        end
      when Array then node.flat_map { |value| leaves(value) }
      else [ node.to_s ]
      end
    end

    def load_locale(name)
      YAML.load_file(Rails.root.join("config/locales/#{name}.yml"))
    end
end
