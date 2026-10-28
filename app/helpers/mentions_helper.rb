# Marks the Character names a prose body contains, and keeps a mention
# visually distinct from a recorded appearance.
#
# The text is always escaped and only the link and its optional note are
# markup, so an Element body containing `<script>` prints as prose rather than
# executing. A name that `MentionIndex` recognized but the Scene does not record
# as present gets the `mention--suggested` style and an accessible note; the link
# still opens the Character, because the record exists even though the presence
# was never recorded.
module MentionsHelper
  # The body with each recognized name linked to its Character. `present` is the
  # set of Character ids the Scene records as present, which is what separates a
  # plain mention from a suggestion. The return value is always safe to render:
  # an unknown body is escaped as one text segment.
  def highlighted_mentions(text, index:, present_character_ids: [])
    return safe_join([ text.to_s ]) if text.blank? || index.nil?

    matches = index.matches(text)
    return safe_join([ text.to_s ]) if matches.empty?

    present = present_character_ids.to_set
    segments = []
    cursor = 0

    matches.each do |match|
      segments << text[cursor...match.offset] if match.offset > cursor
      segments << mention_link(match, suggested: !present.include?(match.character.id))
      cursor = match.offset + match.length
    end

    segments << text[cursor..] if cursor < text.length
    safe_join(segments)
  end

  private
    def mention_link(match, suggested:)
      classes = [ "mention" ]
      classes << "mention--suggested" if suggested

      link_to(
        universe_character_path(universe_slug: Current.universe.slug, id: match.character.id),
        class: classes.join(" "),
        title: suggested ? t("shared.mention.suggested_title") : nil
      ) do
        parts = [ match.text ]
        parts << tag.span(" #{t("shared.mention.suggested_note")}", class: "visually-hidden") if suggested
        safe_join(parts)
      end
    end
end
