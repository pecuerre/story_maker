# Renders a Character's Markdown description for the details page.
#
# The description is author-written Markdown: `##` headings, `**bold**`, lists,
# tables, and inline `[[kind:slug]]` references. Rendering happens in one place
# so every surface shows the same safe HTML, and so the reference syntax is
# resolved against the Character's own Universe rather than trusted as a URL.
#
# A reference is a link only when it names a record the reader can open:
# `[[character:ada]]`, `[[faction:wardens]]`, `[[location:keep]]`, and
# `[[item:lantern]]` are the four Universe kinds. `plot`, `scene`, `rule`, and
# `canon` are also resolved when they exist. A bare `[[slug]]` still works, as
# the older source did; it is looked up across the Universe kinds in order. An
# unknown reference stays exactly as written, so an author sees the typo instead
# of a silently dropped sentence.
#
# A reference inside a code span or a fenced block is an example, not a link,
# and is left alone.
class CharacterDescription
  include Rails.application.routes.url_helpers

  # Redcarpet's safe subset. `filter_html` refuses raw HTML in the stored body;
  # `autolink` keeps a written URL clickable; tables and fenced blocks are part
  # of the interchange prose the author already writes.
  MARKDOWN_OPTIONS = {
    fenced_code_blocks: true,
    autolink: true,
    no_intra_emphasis: true,
    tables: true,
    superscript: false,
    strikethrough: true,
    lax_html_blocks: false,
    space_headers: true
  }.freeze

  ALLOWED_TAGS = %w[
    a blockquote br code del em h1 h2 h3 h4 h5 h6 hr li ol p pre strong sub sup
    table tbody td th thead tr ul
  ].freeze

  ALLOWED_ATTRIBUTES = %w[href rel title].freeze

  # `<code>` and `<pre>` are skipped as whole regions so a reference written as
  # documentation is not turned into a link.
  PROTECTED_HTML = %r{(<(?:code|pre)\b[^>]*>.*?</(?:code|pre)>)}m
  REFERENCE = /\[\[(?:(?<kind>[a-z]+):)?(?<slug>[^\[\]\s]+)\]\]/i

  KIND_MODELS = {
    "character" => Character,
    "faction" => Faction,
    "location" => Location,
    "item" => Item,
    "tech" => Item
  }.freeze

  BARE_LOOKUP = %w[character faction location item].freeze

  attr_reader :universe

  def initialize(universe, text)
    @universe = universe
    @text = text.to_s
  end

  def to_html
    return "".html_safe if @text.blank?

    sanitized = helpers.sanitize(rendered_markdown, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)
    link_references(sanitized).html_safe
  end

  private
    def helpers
      ActionController::Base.helpers
    end

    def rendered_markdown
      renderer = Redcarpet::Render::HTML.new(
        filter_html: true,
        link_attributes: { rel: "noopener noreferrer" }
      )
      Redcarpet::Markdown.new(renderer, MARKDOWN_OPTIONS).render(@text)
    end

    # Split on the protected regions; the captured separators are the odd
    # elements, and only the even ones are prose that may carry a reference.
    def link_references(html)
      html.split(PROTECTED_HTML).map.with_index do |part, index|
        next part if index.odd?

        part.gsub(REFERENCE) do
          match = Regexp.last_match
          reference_html(match[:kind]&.downcase, match[:slug]) || match[0]
        end
      end.join
    end

    def reference_html(kind, slug)
      kind, record = resolve(kind, slug)
      return nil unless record

      href = path_for(kind, record)
      return nil unless href

      %(<a href="#{ERB::Util.html_escape(href)}">#{ERB::Util.html_escape(label_for(record, slug))}</a>)
    end

    # A typed reference may only name the kind it declares. A bare reference is
    # the old source's form and is looked up across the Universe kinds.
    def resolve(kind, slug)
      if kind.present?
        return [ kind, find_typed(kind, slug) ]
      end

      BARE_LOOKUP.each do |candidate|
        record = find_typed(candidate, slug)
        return [ candidate, record ] if record
      end

      plot = find_plot(slug)
      plot ? [ "plot", plot ] : [ nil, nil ]
    end

    def find_typed(kind, slug)
      case kind
      when "plot"
        find_plot(slug)
      when "scene"
        universe.scenes.find_by(slug: slug)
      when "character", "faction", "location", "item", "tech"
        KIND_MODELS.fetch(kind).where(universe_id: universe.id).find_by(slug: slug)
      when "rule", "canon"
        universe.canon_rules.find_by(slug: slug.downcase)
      end
    end

    def find_plot(slug)
      Plot.joins(:story).where(stories: { universe_id: universe.id }).find_by(slug: slug)
    end

    def path_for(kind, record)
      case kind
      when "character"
        universe_character_path(universe_slug: universe.slug, id: record)
      when "faction"
        universe_faction_path(universe_slug: universe.slug, id: record)
      when "location"
        universe_location_path(universe_slug: universe.slug, id: record)
      when "item", "tech"
        universe_item_path(universe_slug: universe.slug, id: record)
      when "plot"
        universe_story_plot_path(universe_slug: universe.slug, story_id: record.story_id, id: record)
      when "scene"
        universe_story_scene_path(universe_slug: universe.slug, story_id: record.story_id, id: record)
      when "rule", "canon"
        universe_canon_rule_path(universe_slug: universe.slug, id: record)
      end
    end

    def label_for(record, slug)
      record.try(:display_string).presence || record.try(:display_label).presence ||
        record.try(:name).presence || slug.titleize
    end
end
