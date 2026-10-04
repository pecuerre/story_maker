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
