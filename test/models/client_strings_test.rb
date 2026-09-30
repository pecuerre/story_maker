require "test_helper"

# The client half of the translation contract.
#
# A Stimulus controller cannot call `I18n.t`, so a client-side string is
# resolved by the server and read by the browser. That boundary is where a
# missing translation stops failing the suite: `raise_on_missing_translations`
# proves `config/locales/es.yml` has every key `en.yml` has, but nothing proved
# that a key a **controller** reads is one of the keys the server sends, or that
# the record-type nouns a record-level error is phrased with exist at all.
#
# These are the tests that close that gap, and they check both directions:
#
#   - every key a controller calls `t()` with resolves in **both** locales and is
#     in the blob the layout renders;
#   - every key the blob sends is one a controller actually reads, so a
#     translation cannot quietly stop being reachable;
#   - every `model_param` a workspace declares has a record subject, so a new
#     workspace cannot fall back to a humanized English parameter.
class ClientStringsTest < ActiveSupport::TestCase
  FIXTURE = Rails.root.join("test/javascript/fixtures/client_strings.en.json")

  # Every `t("…")` call in a shipped controller.
  #
  # Read out of the source rather than repeated here, so a controller that reads
  # a new key is covered the moment it does. The `t(` prefix is what makes this
  # exact: a bare string elsewhere in a controller is not a lookup, and
  # `no_client_string_literals_test.js` is what says a bare string is not allowed
  # there either. The two tests are halves of one contract, and each is what
  # makes the other necessary.
  def controller_keys
    Dir.glob(Rails.root.join("app/javascript/**/*.js"))
      .flat_map { |path| File.read(path).scan(/\bt\(\s*"([\w.]+)"/).flatten }
      .uniq
      .sort
  end

  test "every key a controller reads is a key the server sends" do
    unread = controller_keys - ClientStrings::KEYS

    assert_empty unread,
      "keys read by a controller but absent from ClientStrings::KEYS, so a page " \
      "would render them as the key itself: #{unread.join(', ')}"
  end

  test "every key the server sends is a key a controller reads" do
    # The other direction. A key nothing reads is a translation a translator
    # maintains that no reader can reach, and one that will look current to
    # everyone reviewing the locale file.
    unread = ClientStrings::KEYS - controller_keys

    assert_empty unread,
      "keys in ClientStrings::KEYS that no controller reads, so they are dead " \
      "translations: #{unread.join(', ')}"
  end

  test "the scan actually finds the shipped controllers' keys" do
    # A regex that stopped matching would make the two tests above pass by
    # finding nothing, which is the failure mode a guard written as a scan always
    # has. The count is loose on purpose: what it has to prove is that the scan
    # reads real source, not that it has not been extended.
    assert_operator controller_keys.size, :>, 50
  end

  test "every key a controller reads resolves in every locale this application offers" do
    missing = AppLocale.names.flat_map do |locale|
      controller_keys.reject { |key| I18n.exists?(key, locale) }.map { |key| "#{locale}: #{key}" }
    end

    assert_empty missing, "client keys with no entry in a locale file: #{missing.join(', ')}"
  end

  test "the blob is rendered in the request's language" do
    I18n.with_locale(:es) do
      payload = JSON.parse(ClientStrings.payload)

      assert_equal "es", payload["locale"]
      assert_equal "Cancelar", payload["shared.form.cancel"]
      assert_equal "Guardar los cambios", payload["shared.taxonomy_tree.save_changes"]
      assert_equal "Ampliar", payload["shared.photo_field.zoom"]
      assert_equal "Guardando…", payload["shared.modal_form.saving"]
      assert_equal "No se pudo contactar con la búsqueda.", payload["searches.bar.unreachable"]
    end
  end

  test "a pluralized key travels whole, so the client chooses the form and not the server" do
    # The blob is rendered once per page while the count is only known when a
    # controller asks. A server that resolved the form here would have had to
    # pick one before it knew the number, so the whole hash travels and
    # `Intl.PluralRules` picks — the same rule table the locale file's
    # `one:`/`other:` keys encode.
    I18n.with_locale(:es) do
      entry = JSON.parse(ClientStrings.payload)["searches.bar.type_more"]

      assert_equal({ "one" => "Escribe %{count} carácter más para buscar.",
                     "other" => "Escribe %{count} caracteres más para buscar." }, entry)
    end
  end

  test "the blob names the locale it was resolved in, so the client cannot pick a rule that contradicts it" do
    # A page whose blob and whose `<html lang>` disagreed would choose a plural
    # form from one language's rules and print another's words.
    %i[en es].each do |locale|
      I18n.with_locale(locale) do
        assert_equal locale.to_s, JSON.parse(ClientStrings.payload)["locale"]
      end
    end
  end

  test "the record subject is a whole phrase, because a language needs its determiner somewhere" do
    # English supplies "the" in the phrase; Spanish has to, because its sentence
    # (`shared.record_error`) supplies nothing. A bare noun would need an article
    # the frame cannot know — the same decision `shared.error_summary.heading`
    # makes for the server-rendered summary.
    I18n.with_locale(:en) do
      assert_equal "the event", ClientStrings.subject_for("event")
    end

    I18n.with_locale(:es) do
      assert_equal "este suceso", ClientStrings.subject_for("event")
      assert_equal "esta relación", ClientStrings.subject_for("relation")
    end
  end

  test "every model_param a workspace declares has a record subject" do
    declared = Dir.glob(Rails.root.join("app/views/**/*.erb"))
      .flat_map { |path| File.read(path).scan(/data-modal-form-model-param-value="([\w_]+)"/).flatten }
      .uniq
      .sort

    assert_not_empty declared, "expected to find modal-form model params in the views"
    missing = declared - ClientStrings::RECORD_SUBJECTS

    assert_empty missing,
      "model params with no record subject, so a base error on that workspace " \
      "would print a humanized English parameter: #{missing.join(', ')}"
  end

  test "the English unit-test fixture is the blob the layout would render" do
    # The Bun tests assert English copy. If they read a hand-written stub they
    # would keep passing after a sentence was reworded or a key dropped, so the
    # fixture is compared byte for byte against what the application actually
    # sends for an English request.
    I18n.with_locale(:en) do
      assert_equal ClientStrings.payload, FIXTURE.read.strip,
        "#{FIXTURE.relative_path_from(Rails.root)} is stale; regenerate it with " \
        "`bin/rails runner 'I18n.with_locale(:en) { File.write(" \
        "#{FIXTURE.relative_path_from(Rails.root)}, ClientStrings.payload) }'`"
    end
  end
end
