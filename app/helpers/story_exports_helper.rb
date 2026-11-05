# The printable manuscript's own heading levels, and the scene-notes rows it
# renders.
#
# A Section's heading level follows its depth in the Section tree, and its
# Scenes sit one level below the Section that groups them. The clamp keeps a
# deeply nested story inside HTML's six levels: a document with an `h9` would be
# invalid even though the tree is not.
module StoryExportsHelper
  def manuscript_section_heading(depth)
    "h#{depth + 2 < 6 ? depth + 2 : 6}"
  end

  def manuscript_scene_heading(depth)
    "h#{depth + 3 < 6 ? depth + 3 : 6}"
  end

  # The text printed under one appendix entry's name. A category either prints
  # a one-line summary or the record's full profile. A Markdown profile is
  # rendered with the description dialect but with every `[[kind:slug]]`
  # reference reduced to the name it names and no link, because the document is
  # paper: there is nothing to click, and the entry already sits under its
  # category. Its headings are demoted three levels so they read as that
  # entry's own sections rather than competing with the category title above.
  def manuscript_appendix_text(record, appendix)
    text = record.public_send(appendix.text_method)
    return if text.blank?

    description = MarkdownDescription.new(Current.universe, text)
    if appendix.markdown?
      content_tag(:div, description.to_unlinked_html(heading_offset: 3), class: "manuscript-appendix-description")
    else
      content_tag(:p, description.as_plain_text, class: "manuscript-appendix-summary")
    end
  end

  # The notes above one printed Scene, in the order the block reads: point of
  # view, in-world time, then the author's recorded participants and depicted
  # Events. A row is either `text:` (one value) or `entries:` (name/role pairs).
  #
  # Only the stored presence links are listed, not the Characters who speak
  # without a link: the dialogue below already names every speaker, and a
  # derived speaker has no role to print. Empty data produces no row at all, so
  # a Scene with nothing recorded gets no empty notes box.
  def manuscript_scene_notes(scene)
    rows = []

    if scene.pov_character.present?
      rows << { label: t("story_exports.notes.pov"), text: scene.pov_character.name }
    end

    in_world_time = scene_in_world_time(scene)
    rows << { label: t("story_exports.notes.time"), text: in_world_time } if in_world_time.present?

    characters = scene.scene_characters.to_a.sort_by { |link| [ link.character.name.to_s.downcase, link.character_id ] }
    if characters.any?
      rows << {
        label: t("story_exports.notes.characters"),
        entries: characters.map { |link| [ link.character.name, link.role ] }
      }
    end

    items = scene.scene_items.to_a.sort_by { |link| [ link.item.name.to_s.downcase, link.item_id ] }
    if items.any?
      rows << { label: t("story_exports.notes.items"), entries: items.map { |link| [ link.item.name, link.role ] } }
    end

    locations = scene.scene_locations.to_a.sort_by { |link| [ link.location.name.to_s.downcase, link.location_id ] }
    if locations.any?
      rows << {
        label: t("story_exports.notes.locations"),
        entries: locations.map { |link| [ link.location.name, link.role ] }
      }
    end

    events = scene.scene_events.to_a.sort_by { |link| [ link.position, link.id ] }
    if events.any?
      rows << {
        label: t("story_exports.notes.events"),
        entries: events.map { |link| [ link.event.display_label, link.role ] }
      }
    end

    rows
  end
end
