# Page-relevant details the right utility sidebar shows beside Configuration
# and Collaboration: at most five label-and-count rows about the page the
# reader is on, and nothing at all when there is nothing useful to say.
#
# Every source is scoped to the universe (or the selected story) this request
# is already authorized for, so the inspector never discloses what the page
# itself could not. It is rendered on every page of the universe, which is why
# each row is one bounded count and why the whole panel disappears at zero
# rows instead of rendering an empty box.
module ContextualInspectorHelper
  # The inspector's rows for this page, most relevant first, capped at five.
  # Each row is `[ label, value ]`, ready for the partial to render.
  def contextual_inspector_rows
    return @contextual_inspector_rows if defined?(@contextual_inspector_rows)

    rows = []

    if (story = Current.story)
      rows << [ t("inspector.sections"), story.sections.count ]
      rows << [ t("inspector.scenes"), story.scenes.count ]
    end

    if (record = selected_record)
      case record
      when Character
        rows << [ t("inspector.relations"),
          record.relations_as_character1.count + record.relations_as_character2.count ]
        rows << [ t("inspector.ownerships"), record.ownerships.count ]
      when Item
        rows << [ t("inspector.ownerships"), record.ownerships.count ]
      end
    end

    @contextual_inspector_rows = rows.first(5)
  end

  # The record the page is about, when it is about one: a details page loads
  # it into an instance variable, so the inspector can read it without a
  # second lookup. Nil on indexes and on every page without a selected record.
  def selected_record
    name = %i[character location item event section story relation ownership].detect do |field|
      instance_variable_defined?(:"@#{field}") && (record = instance_variable_get(:"@#{field}")) && record.is_a?(ActiveRecord::Base)
    end

    return nil unless name

    instance_variable_get(:"@#{name}")
  end
end
