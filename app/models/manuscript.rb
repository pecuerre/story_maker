# One Story read as a book: its Sections in tree order and its Scenes in
# narrative order, with the prose assembled from the Scene Elements.
#
# This is a value object rather than a view because the same assembly answers
# three questions the export page asks — which Sections hold which Scenes, what
# a Scene's notes are, and which Universe records an appendix lists — and the
# printable page must not pay a query per Scene to answer them.
#
# `scope` is a **URL value**, not a translated label, and the three values are
# the export page's three choices:
#
# - `prose`       the Section headings, Scene titles, and the written Elements;
# - `front_matter` the same, plus each Scene's point of view, in-world time,
#                  participants, and depicted Events;
# - `bible`       the same, plus the Universe's Characters, Locations, Items,
#                  and Events as appendices.
#
# `final_only` is a second, independent choice: it narrows the printed Scenes to
# `Scene::FINAL_STATUS`, leaving the chosen scope's content rules untouched.
#
# A stored record is all an export ever contains. A remembered change that has
# not been applied is a draft of the author's own work and is not part of the
# Story yet, so it is outside this read path by construction: the Story, its
# Sections, and its Scenes are read through the live associations only.
class Manuscript
  SCOPES = %w[ prose front_matter bible ].freeze
  DEFAULT_SCOPE = "prose"

  # A Section and the Scenes directly under it, with its child Sections nested
  # below. `depth` is the tree level, which is what the printed heading level
  # follows.
  SectionNode = Struct.new(:section, :depth, :scenes, :children, keyword_init: true)

  # One appendix category: a label key rather than a translated string, because
  # this object is built before the request's locale is known to it, the record
  # method that names each entry, and the record method whose text the appendix
  # prints beside that name. An Event's own label is `display_label` because a
  # date-only Event has no title to print.
  Appendix = Struct.new(:label_key, :records, :label_method, :summary_method, keyword_init: true)

  attr_reader :story, :scope

  def self.for(story, scope: DEFAULT_SCOPE, final_only: false)
    new(story, scope: scope, final_only: final_only)
  end

  # An unknown or absent value is the plain-prose export rather than an error:
  # the value arrives from a form or a bookmark, and the conservative document
  # is the one that adds nothing the author did not ask for.
  def self.scope(value)
    SCOPES.include?(value.to_s) ? value.to_s : DEFAULT_SCOPE
  end

  def initialize(story, scope: DEFAULT_SCOPE, final_only: false)
    @story = story
    @scope = self.class.scope(scope)
    @final_only = ActiveModel::Type::Boolean.new.cast(final_only)
    @sections = story.sections.reorder(:position, :id).to_a
    @scenes = preloaded_scenes
  end

  # Whether the reader asked for only final Scenes. This is a separate choice
  # from the content scope: the scope decides what a printed Scene carries, and
  # this decides which Scenes print at all.
  def final_only?
    @final_only
  end

  # No printed Scene at all. A Story whose Sections exist but whose Scenes are
  # all filtered out is empty for this document, so the page states that rather
  # than printing headings over nothing.
  def empty?
    @scenes.empty?
  end

  # Root Section nodes, in position order, with their children already nested.
  def sections
    @sections_tree ||= begin
      children = @sections.group_by(&:parent_id)
      grouped_scenes = @scenes.group_by(&:section_id)
      build_nodes(nil, children, grouped_scenes, [], 0)
    end
  end

  # Scenes that belong to no Section printed in the tree, including a Scene whose
  # Section is missing, detached from the root, or no longer part of this Story.
  # They keep their narrative order and are printed after the Section tree,
  # because a book cannot interleave an ungrouped Scene between two chapters
  # without inventing a chapter for it.
  def ungrouped_scenes
    @ungrouped_scenes ||= begin
      grouped_ids = section_ids(sections)
      @scenes.reject { |scene| grouped_ids.include?(scene.section_id) }
    end
  end

  # The notes are part of the front-matter scope and of the larger one that
  # contains it.
  def scene_notes?
    scope == "front_matter" || bible?
  end

  def bible?
    scope == "bible"
  end

  # The Story's prose mention index. A printable page highlights a recognized
  # name exactly as Scene Details does, but the document is assembled from the
  # Scenes it already loaded, so the index is built once from this Universe's
  # Characters and reused for every Element.
  def mention_index
    @mention_index ||= MentionIndex.new(universe.characters.reorder(:name, :id).to_a)
  end

  # The Character ids recorded as present in a Scene, using only the
  # associations `preloaded_scenes` already read. A mention is highlighted
  # differently when the Character is not in this set; the set never decides
  # whether the name is a mention.
  def participant_ids(scene)
    @participant_ids ||= {}
    @participant_ids[scene.id] ||= begin
      links = scene.scene_characters.map(&:character_id)
      speakers = scene.scene_elements.flat_map do |element|
        element.characters.map(&:id) + element.scene_dialogue_turns.map(&:speaker_id)
      end

      (links + speakers).uniq.to_set
    end
  end

  # Characters, Locations, Items, and Events of this Story's Universe, each
  # category skipped when it is empty. A category is the workspace's own title
  # key, so the appendix calls the records what every workspace calls them.
  def appendices
    return @appendices if defined?(@appendices)

    @appendices = if bible?
      [
        Appendix.new(label_key: "characters.title", records: universe.characters.reorder(:name, :id).to_a,
          label_method: :name, summary_method: :at_a_glance),
        Appendix.new(label_key: "locations.title", records: universe.locations.reorder(:name, :id).to_a,
          label_method: :name, summary_method: :description),
        Appendix.new(label_key: "items.title", records: universe.items.reorder(:name, :id).to_a,
          label_method: :name, summary_method: :description),
        Appendix.new(label_key: "events.title", records: universe.events.reorder(:name, :id).to_a,
          label_method: :display_label, summary_method: :description)
      ].reject { |appendix| appendix.records.empty? }
    else
      []
    end
  end

  private
    def universe
      story.universe
    end

    # Every Scene of the Story in narrative order, with everything the notes and
    # the prose read preloaded. One fixed set of queries serves a Story of any
    # length. A final-only document narrows the same relation, so its Scenes,
    # Section tree, and mention index all agree about what is printed.
    def preloaded_scenes
      relation = story.scenes
        .includes(
          :pov_character,
          { scene_characters: :character },
          { scene_items: :item },
          { scene_locations: :location },
          { scene_events: :event },
          { scene_elements: [ :characters, { scene_dialogue_turns: :speaker } ] }
        )
      relation = relation.where(status: Scene::FINAL_STATUS) if final_only?
      relation.reorder(:position, :id).to_a
    end

    # `visited` stops a corrupt parent cycle from looping, and a Section whose
    # parent is not part of this Story is left out of the tree rather than
    # reading a foreign Section.
    def build_nodes(parent_id, children, grouped_scenes, visited, depth)
      (children[parent_id] || []).filter_map do |section|
        next if visited.include?(section.id)

        SectionNode.new(
          section: section,
          depth: depth,
          scenes: grouped_scenes.fetch(section.id, []),
          children: build_nodes(section.id, children, grouped_scenes, visited + [ section.id ], depth + 1)
        )
      end
    end

    # Every Section the tree actually printed, so a Scene grouped under a
    # detached Section is printed as ungrouped rather than disappearing.
    def section_ids(nodes)
      nodes.flat_map { |node| [ node.section.id, *section_ids(node.children) ] }
    end
end
