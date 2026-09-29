module MembershipsHelper
  # The access levels the membership form offers, as `[label, value]` pairs for
  # `select`.
  #
  # The three forms on this workspace — grant, and the per-row change on the
  # index — all need the same list, so it is built once here rather than being
  # spelled out three times. The *value* is the `read`/`write`/`admin` string
  # that travels in the form field and is stored on the record; only the label
  # beside it is translated. That is the rule ADR 0016 states for every value
  # that travels in a URL or a form field, and it is why this is a join of a
  # constant and a locale rather than a translated constant.
  def membership_access_level_options
    UniverseMembership::ACCESS_LEVELS.keys.map do |level|
      [ t("memberships.access_levels.#{level}"), level ]
    end
  end
end
