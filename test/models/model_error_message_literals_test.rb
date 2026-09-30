require "test_helper"

# A model error message must be a key, not a literal.
#
# This is the server-side half of the same gate `no_client_string_literals_test.js`
# puts on `app/javascript`, and it exists because the two checks the translation
# contract already had could not see this class of string at all:
#
#   - `TranslationsTest` compares the two locale files against each other, so a
#     sentence that is in neither file is invisible to it.
#   - `SpanishChromeTest` searched a rendered body for the English values the
#     locale files define. A message that bypassed a key is not one of them, and
#     a page only reaches a validation message by *failing* to save, so every
#     page it rendered was a success.
#
# The result was a Spanish page reading "Color de fondo must be a hex color like
# #d3d3d3" with a green suite, across twenty-six call sites in fifteen models.
# Nothing here checks that a given message is *well* translated — that is what
# the two checks above and the request tests in `SpanishChromeTest` are for. This
# one only asserts the shape that lets them be true: the message is reached
# through `I18n`.
#
# A **user-facing literal** is a quoted string handed to `errors.add` or to a
# `validates` option named `message:`. A translation is an `I18n.t(...)` call or a
# constant holding one, and both are allowed — so the allowlist is empty, because
# a sentence written where a key belongs has exactly one correct home and naming
# it in a list here would be a second place to forget.
class ModelErrorMessageLiteralsTest < ActiveSupport::TestCase
  # `errors.add(:parent, "…")` and `errors.add(:base, "…")` with a literal
  # second argument. The attribute is whatever the validation chose, so this
  # matches the call and inspects the argument rather than naming attributes.
  ERRORS_ADD = /errors\.add\(\s*[\w:]+,\s*(?<message>"[^"]*")/.freeze

  # `validates :bgcolor, format: { …, message: "…" }` and its siblings, in
  # either the braced or the unbraced option style.
  VALIDATES_MESSAGE = /message:\s*(?<message>"[^"]*")/.freeze

  # A heredoc or a multi-line `%()` message would be missed by both patterns
  # above. Nothing in `app/models` writes one today; if a message ever grows
  # past one line it should be a key, which is the point of the gate.
  test "no model raises a validation message as a literal string" do
    offenders = model_sources.flat_map do |path|
      source = path.read

      [ ERRORS_ADD, VALIDATES_MESSAGE ].flat_map do |pattern|
        source.enum_for(:scan, pattern).filter_map do
          match = Regexp.last_match
          next unless message_is_chrome?(match[:message])

          "#{path.relative_path_from(Rails.root)}: #{match[:message]}"
        end
      end
    end

    assert_empty offenders, <<~MESSAGE
      These model validation messages are English literals rather than keys, so a
      Spanish reader gets an English sentence inside a translated page. Give each
      one an `I18n.t` key in both config/locales/en.yml and config/locales/es.yml:

        #{offenders.join("\n        ")}
    MESSAGE
  end

  # A key read from a variable is **not** an offence. `ClientStrings`,
  # `Search::Kinds`, and `SectionPaths` all resolve a key held in a constant or
  # built by lookup on purpose, and `HasColor::HEX_COLOR_MESSAGE` is the same
  # pattern for a validation message: a constant holds an I18n key so two call
  # sites cannot disagree about it. This gate asserts only the narrower thing
  # that was actually wrong — a sentence written where a key belongs.

  private
    def model_sources
      (Rails.root.join("app/models").glob("**/*.rb")).sort
    end

    # A literal is chrome when it reads as a sentence rather than as a name. The
    # only literals that legitimately reach these two positions are none today,
    # so this is deliberately permissive about *shape* and absolute about
    # *position*: a quoted string in an error slot is chrome, and a translator
    # should be the one deciding what it says.
    def message_is_chrome?(literal)
      literal.length > 2 # `""` carries no sentence
    end
end
