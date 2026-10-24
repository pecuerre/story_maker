require "test_helper"

# The translation contract itself, rather than any one page's copy.
#
# The failures guarded here are all invisible to a suite that runs in the default
# locale. A key that exists in English and not in Spanish renders English to a
# Spanish reader. A translation that drops an interpolation renders a literal
# "%{name}". A translation that drops a plural form fails at render time in one
# locale only. And a hand-written Spanish block that translates a key Rails does
# not define is a translation of nothing, which is how a maintained subset rots
# across a Rails upgrade.
#
# The comparison is between this application's own two locale files, not the
# whole loaded `I18n` backend: Rails defines `errors.messages.*`,
# `datetime.distance_in_words.*`, and `support.array.*` in English only, so they
# can never appear in `en.yml`. Those are checked against the real Rails key set
# instead. Ownership is decided **per key**, read from the framework's own locale
# files, so an application key that happens to sit inside a framework namespace
# is still compared.
class TranslationsTest < ActiveSupport::TestCase
  LOCALE_FILES = %w[config/locales/en.yml config/locales/es.yml].freeze

  PLURAL_FORMS = %w[zero one two few many other].freeze

  test "the two locale files parse and each holds exactly one locale" do
    assert_equal %w[en], load_locale("en").keys.map(&:to_s)
    assert_equal %w[es], load_locale("es").keys.map(&:to_s)
  end

  test "no locale file repeats a mapping key" do
    # A repeated key in one YAML file is not an error to Psych: the later value
    # silently replaces the earlier one, so the discarded half simply stops
    # being translated and nothing in the suite notices. `es.yml` had two
    # `errors:` blocks, and the second one — the Rails subset — was replacing the
    # application's own `unavailable_account` and `rate_limited` strings.
    LOCALE_FILES.each do |file|
      repeated = repeated_keys(Psych.parse_file(Rails.root.join(file)))

      assert_empty repeated, "#{file} repeats a key, so the earlier value is discarded: #{repeated.join(', ')}"
    end
  end

  test "the Spanish translations carry exactly the English key set" do
    en = application_keys("en")
    es = application_keys("es")

    missing = en.keys - es.keys
    extra = es.keys - en.keys

    assert_empty missing, "keys in en.yml with no es.yml entry: #{missing.join(', ')}"
    assert_empty extra, "keys in es.yml with no en.yml entry: #{extra.join(', ')}"
  end

  test "every interpolation an English entry uses is used by its Spanish entry too" do
    # A translation that drops an interpolation renders the literal "%{name}",
    # and one that renames an interpolation it was never given raises when it is
    # rendered. Comparing the placeholder names is what catches both.
    en = application_keys("en")
    es = application_keys("es")

    mismatched = en.filter_map do |key, value|
      next unless value.is_a?(String) && es[key].is_a?(String)
      next if placeholders(value) == placeholders(es[key])

      key
    end

    assert_empty mismatched, "interpolation placeholders differ: #{mismatched.join(', ')}"
  end

  test "no translation uses an interpolation name I18n reserves" do
    # `locale`, `default`, `scope`, and `count` are I18n options, not
    # interpolation variables: `t(key, locale: "Español")` asks I18n to translate
    # *in* a locale called Español and raises `I18n::InvalidLocale`. `count` is
    # the exception, and is only a pluralization input when the key has plural
    # forms, so it is allowed there and nowhere else.
    reserved = %w[default scope locale raise]
    offending = {}

    %w[en es].each do |locale|
      application_keys(locale).each do |key, value|
        next unless value.is_a?(String)

        names = placeholders(value) & reserved
        offending["#{locale}:#{key}"] = names if names.any?
      end
    end

    assert_empty offending, "reserved I18n options used as interpolations: #{offending.inspect}"
  end

  test "every pluralized entry defines the same plural forms in both locales" do
    en = application_keys("en")
    es = application_keys("es")

    mismatched = en.filter_map do |key, value|
      next unless plural_forms?(value)
      next if value.keys.to_set == es[key].keys.to_set

      key
    end

    assert_empty mismatched, "plural forms differ: #{mismatched.join(', ')}"
  end

  test "no Spanish value is left as a missing-translation placeholder" do
    leaked = application_keys("es").filter_map do |key, value|
      key if value.is_a?(String) && value.include?("translation missing")
    end

    assert_empty leaked, "Spanish values that look like missing translations: #{leaked.join(', ')}"
  end

  test "every Spanish translation of a Rails string mirrors a key Rails defines" do
    invented = framework_keys("es").reject { |key| I18n.exists?(key, :en) }

    assert_empty invented, "es.yml translates keys Rails does not define: #{invented.join(', ')}"
  end

  test "the Rails strings translated here keep the interpolations Rails uses" do
    mismatched = framework_keys("es").filter_map do |key|
      english = I18n.t(key, locale: :en, raise: true)
      spanish = I18n.t(key, locale: :es, raise: true)
      next if placeholders(english) == placeholders(spanish)

      key
    end

    assert_empty mismatched, "Rails interpolations differ: #{mismatched.join(', ')}"
  end

  test "every locale this application offers has a locale file" do
    # An `AppLocale` name with no `es.yml`-style file behind it would render
    # every application key missing, so the offered list and the files are
    # asserted to be the same list.
    offered = AppLocale.names.map { |name| "config/locales/#{name}.yml" }

    assert_equal offered.sort, LOCALE_FILES.sort
  end

  test "every root record-type noun resolves in both locales, in the plural" do
    # These resolve dynamically: a workspace passes `count_label: "character"` and
    # `count_with_label` calls `t(label, count: count)`, so a grep cannot see that
    # they are used. A root noun that stopped resolving would raise in the test
    # environment and render "translation missing" in production — on every count
    # badge in the application.
    nouns = %w[character conflict entry event item location member ownership record
               relation scene section story tag universe]

    %i[en es].each do |locale|
      I18n.with_locale(locale) do
        nouns.each do |noun|
          assert_predicate I18n.t(noun, count: 1), :present?, "#{locale}: #{noun} (one)"
          assert_predicate I18n.t(noun, count: 3), :present?, "#{locale}: #{noun} (other)"
        end
      end
    end
  end

  # The drafts page prints one label per remembered value, resolved through
  # `human_attribute_name`. A key the locale files have not named falls back to a
  # humanized English column name, which is the documented behaviour of
  # `human_attribute_name` — and on that page it is a Spanish reader seeing English
  # beside the page's own Spanish chrome.
  #
  # The three ways a label resolves are `DraftsHelper`'s: a shared key for the two
  # photo writers and `position`, an id list through the collection it fills, and
  # everything else through the attribute itself (a single id having already been
  # resolved to the association it points at). Each one therefore has to name its
  # label in **both** files, and nothing above could catch it when it did not:
  # `TranslationsTest` compares the two files against each other, so a key in
  # neither is invisible to it.
  #
  # The payload keys are read out of the controllers rather than listed here, so
  # this cannot go stale the way a list would — a new permitted attribute on any
  # editor fails the suite until it is named. `DraftsHelper.label_field` does the
  # resolving rather than this file repeating it, so the assertion cannot pass
  # against a helper that resolves differently.
  test "every attribute a remembered change can print has a name in both locales" do
    unnamed = permitted_payload_keys.filter_map do |model, key, association|
      key = key.to_s
      next if stripped_before_remembering.include?([ model.name, key ])

      missing = missing_locales(model, key, association)
      [ model.name, key, missing ] if missing.any?
    end

    assert_empty unnamed, <<~MESSAGE
      These payload keys have no label in one or both locale files, so the drafts page
      prints a humanized English column name for them. Name each one where its label
      belongs — activerecord.attributes.<model>.<attribute> for a model's own
      attribute, or drafts.attributes for the two photo writers and position:

        #{unnamed.map { |model, key, missing| "#{model} #{key}: #{missing.join(", ")}" }.join("\n        ")}
    MESSAGE
  end

  test "every taxonomy the tree can render has a name for its empty state" do
    # The tree resolves its empty-state title from the `model_param` a caller
    # passes (`t("taxonomies.#{model_param}.none_yet")`), so a new taxonomy is a
    # new call site and could arrive without its key. The model params actually in
    # use are read out of the taxonomy index views rather than repeated here, so
    # this cannot go stale.
    model_params = Dir.glob(Rails.root.join("app/views/**/*_tags/index.html.erb"))
      .map { |path| File.read(path) }
      .filter_map { |source| source[/model_param: "(\w+)"/, 1] }
      .uniq
      .sort

    assert_not_empty model_params, "expected to find taxonomy model params in the index views"
    model_params.each do |model_param|
      assert I18n.exists?("taxonomies.#{model_param}.none_yet", :en),
        "no empty-state key for the #{model_param} taxonomy"
      assert I18n.exists?("taxonomies.#{model_param}.none_yet", :es),
        "no Spanish empty-state key for the #{model_param} taxonomy"
    end
  end

  private
    # The `[model, payload_key, id_list_association]` triples one mutation
    # controller can remember, read out of the twenty controllers that include
    # `DraftMutation` rather than repeated here.
    #
    # The permitted list is `params.expect(model: [ … ])`, so the source is
    # scanned for that call and its symbols are read. `*photo_params` stands for
    # the two virtual photo writers, which are named by `SHARED_LABEL_KEYS` rather
    # than by an attribute, and are expanded here so they are still visited.
    def permitted_payload_keys
      @permitted_payload_keys ||= Dir.glob(Rails.root.join("app/controllers/**/*_controller.rb"))
        .flat_map { |path| permitted_in(path) }
    end

    def permitted_in(path)
      source = File.read(path)
      return [] unless source.include?("include DraftMutation")

      # The call is `params.expect(model: [ … ])`, so the bracket is matched to
      # its own close rather than to the first `]` in the body, which is the one
      # inside a `{ x_ids: [] }` entry.
      source.scan(/params\.expect\(\s*(\w+):\s*\[(.*?)\]\s*\)/m).flat_map do |param, body|
        # The parameter is a model param, so the class is the underscored singular
        # of it rather than the param itself.
        model = param.singularize.camelize.constantize
        # `*photo_params` stands for the two virtual photo writers. They have no
        # attribute name because they are not columns, so they are expanded to
        # reach `SHARED_LABEL_KEYS` and skipped there.
        keys = body.include?("photo_params") ? [ *PhotoParams::PHOTO_PARAMS.map(&:to_s) ] : []
        keys += body.scan(/:(\w+)|\{\s*(\w+):/).map { |scalar, list| scalar || list }

        keys.filter_map { |key| [ model, key, id_list_association(model, key) ] if key.present? }
      end
    end

    # The collection a submitted id list fills, derived the way
    # `DraftsHelper#id_list_association` derives it, so a key whose collection is
    # named is visited as the association rather than as the raw `_ids` column.
    def id_list_association(model, key)
      if key.end_with?("_ids")
        model.reflect_on_association(key.delete_suffix("_ids").pluralize)
      elsif key.end_with?("_id")
        model.reflect_on_association(key.delete_suffix("_id"))
      end
    end

    # The locales in which one payload key has no label, resolved the way
    # `DraftsHelper#draft_change_label` resolves it rather than re-deriving the
    # three shapes here. The shared keys are checked by key and the rest by
    # attribute name, so a passing assertion means the page itself can render.
    def missing_locales(model, key, association)
      shared = DraftsHelper.shared_label_key(key)
      return %i[en es].reject { |locale| I18n.exists?(shared, locale) } if shared.present?

      field = DraftsHelper.label_field(model, key, association)
      return [] if field.blank?

      attribute = "activerecord.attributes.#{model.model_name.i18n_key}.#{field}"

      %i[en es].reject { |locale| I18n.exists?(attribute, locale) }
    end

    # A permitted attribute that never reaches a payload, so naming it would be a
    # key nothing renders. `SceneElementsController#scene_element_attributes`
    # drops `remove_speakers` before the attributes are assigned *and* before they
    # are remembered: it is the confirmation that a Narration keeps no speakers,
    # not a value about the record.
    def stripped_before_remembering
      [ [ "SceneElement", "remove_speakers" ] ]
    end

    def load_locale(name)
      YAML.load_file(Rails.root.join("config", "locales", "#{name}.yml"))
    end

    # Everything the application owns: the two files minus the keys Rails itself
    # defines. The split is made per key, not per namespace, because this
    # application owns `errors.unavailable_account` and `errors.rate_limited`
    # beside Rails' own `errors.messages.*` and `errors.format`. A namespace-wide
    # exclusion dropped those two out of the comparison, so a key added to
    # `en.yml` and forgotten in `es.yml` would have failed no test at all.
    def application_keys(locale)
      keys(locale).reject { |key, _| rails_keys.include?(key) }
    end

    def framework_keys(locale)
      keys(locale).select { |key, _| rails_keys.include?(key) }.keys
    end

    def keys(locale)
      walk(load_locale(locale).fetch(locale), [])
    end

    # The keys Rails defines, read from the framework's own locale files rather
    # than assumed from a hardcoded list, so a Rails upgrade that adds or moves a
    # subtree is classified correctly without editing this test. `I18n.exists?`
    # cannot answer this: the application's own `en.yml` is merged into the `:en`
    # backend, so its keys answer `true` exactly like Rails' do.
    def rails_keys
      @rails_keys ||= begin
        paths = Gem.loaded_specs
          .values_at("activemodel", "activesupport", "activerecord", "actionview")
          .compact
          .flat_map { |gem| Dir[File.join(gem.full_gem_path, "lib", "**", "locale", "*.yml")] }

        paths.each_with_object({}) do |path, out|
          data = begin
            YAML.load_file(path)
          rescue StandardError
            nil
          end
          next unless data.is_a?(Hash)

          data.each_value do |tree|
            walk(tree, [], out) if tree.is_a?(Hash)
          end
        end
      end
    end

    # A leaf is a String; a Hash whose keys are all plural forms is one
    # pluralized entry, so it is kept whole rather than walked into. That is what
    # lets the placeholder comparison treat `one:`/`other:` as a single
    # translated sentence.
    def walk(node, prefix, out = {})
      if node.is_a?(Hash) && !plural_forms?(node)
        node.each { |key, value| walk(value, prefix + [ key.to_s ], out) }
      else
        out[prefix.join(".")] = node
      end
      out
    end

    def plural_forms?(node)
      return false unless node.is_a?(Hash)

      keys = node.keys.map(&:to_s)
      keys.any? { |key| key.in?(PLURAL_FORMS) } && keys.all? { |key| key.in?(PLURAL_FORMS) }
    end

    def placeholders(value)
      value.to_s.scan(/%\{(\w+)\}/).flatten.sort
    end

    # Every mapping key in the parsed document as a full dotted path, at any
    # depth, so a repeat is found wherever it is written rather than only at the
    # top level. The path matters: `shared.label` and `settings.label` are two
    # different keys, while two `errors:` blocks are the same key twice.
    def repeated_keys(node, path = [], seen = [])
      case node
      when Psych::Nodes::Mapping
        node.children.each_slice(2) do |key, value|
          child = path + [ key.respond_to?(:value) ? key.value.to_s : "?" ]
          seen << child.join(".")
          repeated_keys(value, child, seen) if value.is_a?(Psych::Nodes::Node)
        end
      when Psych::Nodes::Sequence, Psych::Nodes::Document
        node.children.each { |child| repeated_keys(child, path, seen) if child.is_a?(Psych::Nodes::Node) }
      end
      seen.tally.select { |_key, count| count > 1 }.keys
    end
end
