# Renders a record's Markdown description for its details page, and the
# `[[kind:slug]]` references an author also writes in the short summary.
#
# The description is author-written Markdown: `##` headings, `**bold**`, lists,
# tables, and inline references. Rendering happens in one place so every surface
# shows the same safe HTML, and so the reference syntax is resolved against the
# record's own Universe rather than trusted as a URL. Characters and Factions
# share this dialect; a page reaches it through
# `ApplicationHelper#markdown_description_html`.
#
# A summary is one line of plain text rather than Markdown, so it has two
# narrower renderings of the same reference syntax rather than the full dialect:
# `#to_inline_html` links the record it names at the top of the details page,
# and `#as_plain_text` names that record without a link in a list row, which
# already carries its own Details link.
#
# A reference is a link only when it names a record the reader can open:
# `[[character:ada]]`, `[[faction:wardens]]`, `[[location:keep]]`, and
# `[[item:lantern]]` are the four Universe kinds. `plot`, `scene`, `rule`, and
# `canon` are also resolved when they exist. A canon rule keeps the reference's
# own ledger id as its label (`[[canon:K47]]` reads as `K47`), because that id is
# how prose cites a rule; every other kind is labeled with the record's name. A
# bare `[[slug]]` still works, as the older source did; it is looked up across
# the Universe kinds in order. An
# unknown reference stays exactly as written, so an author sees the typo instead
# of a silently dropped sentence.
#
# A reference inside a code span or a fenced block is an example, not a link,
# and is left alone.
class MarkdownDescription
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

  # One line of plain text with its references linked, for the top of a details
  # page. Nothing here is Markdown: the prose is escaped exactly as written, so
  # a summary containing `##` or `**` keeps those characters, and only a
  # reference becomes an element.
  def to_inline_html
    return "".html_safe if @text.blank?

    html = String.new
    cursor = 0
    @text.to_enum(:scan, REFERENCE).each do
      match = Regexp.last_match
      html << ERB::Util.html_escape(@text[cursor...match.begin(0)].to_s)
      html << (reference_html(match[:kind]&.downcase, match[:slug]) || ERB::Util.html_escape(match[0]))
      cursor = match.end(0)
    end
    html << ERB::Util.html_escape(@text[cursor..].to_s)
    html.html_safe
  end

  # The same line with each reference reduced to the name of the record it
  # names (or, for a canon rule, its ledger id) and no link at all, for a list
  # row: the row already carries a Details link, and a second one inside a
  # two-line preview competes with it. An
  # unresolved reference stays exactly as written, the same rule the description
  # follows, so a typo stays visible instead of silently vanishing. The value is
  # plain text; the view escapes it.
  def as_plain_text
    @text.gsub(REFERENCE) do
      match = Regexp.last_match
      kind, record = resolve(match[:kind]&.downcase, match[:slug])
      record ? label_for(kind, record, match[:slug]) : match[0]
    end
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

      %(<a href="#{ERB::Util.html_escape(href)}">#{ERB::Util.html_escape(label_for(kind, record, slug))}</a>)
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

    # A canon rule is cited by its ledger id, so the reference stays its own
    # label: `[[canon:K47]]` reads as `K47` rather than the rule's full name,
    # which would repeat the rule inside the sentence citing it. Every other
    # kind names the record it links to.
    def label_for(kind, record, slug)
      return slug if %w[rule canon].include?(kind)

      record.try(:display_string).presence || record.try(:display_label).presence ||
        record.try(:name).presence || slug.titleize
    end
end
