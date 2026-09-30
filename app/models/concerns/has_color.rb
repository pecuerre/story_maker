module HasColor
  extend ActiveSupport::Concern

  # A callable, not a resolved string. `included do` runs when the class loads,
  # so `I18n.t` called here would resolve once — in whatever locale happened to
  # load the class first — and every later request would validate against that one
  # language. Rails evaluates a callable message per validation, which is where
  # `I18n.locale` is the locale of the request being validated. This is the same
  # rule `ModalFields` and `Search::Scope` follow; see `features/i18n.md`.
  #
  # One key for both columns: the message is the same sentence whichever colour
  # rejected the value, so a second key would be a second place to translate it.
  # Rails calls a callable message with the record and the validation's options,
  # so the lambda takes both and ignores them.
  HEX_COLOR_MESSAGE = ->(_record, _data) { I18n.t("shared.errors.color.must_be_hex") }

  included do
    validates :bgcolor, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: HEX_COLOR_MESSAGE }
    validates :fgcolor, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: HEX_COLOR_MESSAGE }
  end
end
