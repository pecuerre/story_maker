require "test_helper"

# Guards the documentation itself, because the docs are the input every other agent and the
# owner work from. A wrong duplicate is worse than a missing fact: an assistant that finds a
# confident, well-written, wrong paragraph acts on it, whereas an absent fact sends it to the
# code. These tests keep the documentation honest about itself, so drift is caught by the
# suite instead of by an agent discovering it mid-task.
class DocsTest < ActiveSupport::TestCase
  DOCS_ROOT = Rails.root.join("docs")
  # Historical records are deliberately frozen: an ADR states what was decided at the time, and
  # the delivery history states what used to be true and why. Both are allowed to disagree with
  # the code now, so they are excluded from link and heading checks.
  HISTORICAL_GLOBS = [ "docs/adr/**/*.md", "docs/delivery_history.md" ].freeze

  # The documentation's existing duplication debt: a fact more than one document currently
  # states, pending the one-fact-one-home refactor. Keep it sorted; remove a document from an
  # entry as the duplication is resolved, and delete the entry once one owner remains. See the
  # heading-ownership test below for why each entry names its owners rather than just its heading.
  #
  # Empty since 2026-09-30: the one-fact-one-home refactor moved each feature into docs/features/
  # and gave the cross-cutting page shapes a single owner, so every entry was resolved. An entry
  # added here means a fact has gained a second owner again, and the fix is to give it one home
  # rather than to extend this list.
  KNOWN_DUPLICATED_HEADINGS = {}.freeze

  # The changelog's entry-length ceiling. CHANGELOG.md is the short form — one or two sentences
  # naming the subject — and docs/delivery_history.md is where the reasoning lives. A paragraph in
  # the short form is the one thing that makes the file unreadable: it answers "why?" where the
  # reader asked "what and when?", and it buries the entries around it. The ceiling is a proxy for
  # that, not the definition of it, so it is set where a careful two-sentence summary still fits
  # with room to spare and a paragraph does not.
  CHANGELOG_ENTRY_WORD_LIMIT = 60

  test "every relative markdown link resolves" do
    broken = markdown_files.flat_map { |file| broken_links(file) }

    assert_empty broken,
      "Broken relative links (a dead link sends the reader nowhere):\n" \
      "#{broken.map { |file, link| "  #{file} -> #{link}" }.join("\n")}"
  end

  test "every cross-doc section anchor resolves" do
    # A link to a heading that no longer exists renders as plain text in most Markdown
    # viewers, so a renamed section silently loses its target.
    broken = markdown_files.flat_map { |file| broken_anchors(file) }

    assert_empty broken,
      "Anchors that no longer exist:\n" \
      "#{broken.map { |file, anchor| "  #{file} -> ##{anchor}" }.join("\n")}"
  end

  test "no section heading is owned by two documents" do
    # The one-fact-one-home rule. A duplicated heading is how a second source of truth is
    # introduced, which is how a doc drifts out of sync with the code without anyone noticing.
    #
    # KNOWN_DUPLICATED_HEADINGS is the documentation's existing duplication debt, recorded here
    # so the suite is green while the debt is paid down. Each entry names the heading *and* the
    # documents that currently own it, and it may only ever shrink: a document dropping out of an
    # entry keeps the suite green, while a new document joining one fails it. That is deliberate,
    # because the failure this test exists to catch is a fact gaining a second owner, and an
    # allowlist keyed on the heading alone would permit exactly that. An empty hash is the goal
    # and the only acceptable end state.
    owners = Hash.new { |hash, key| hash[key] = [] }

    markdown_files.each do |file|
      headings(file).each { |heading| owners[heading] << relative(file) }
    end

    duplicated = owners.select { |_heading, files| files.size > 1 }
      .reject { |heading, files| (files - KNOWN_DUPLICATED_HEADINGS.fetch(heading, [])).empty? }

    assert_empty duplicated,
      "A heading owned by more than one document:\n" \
      "#{duplicated.map { |heading, files| "  #{heading.inspect} in #{files.join(', ')}" }.join("\n")}"
  end

  test "every documentation file is listed in the docs index" do
    index = DOCS_ROOT.join("README.md").read

    unlisted = markdown_files
      .map { |file| relative(file) }
      .reject { |file| file == "docs/README.md" }
      .reject { |file| historical?(file) }
      .reject { |file| file.start_with?("docs/adr/") }
      .reject { |file| index.include?(File.basename(file)) }

    assert_empty unlisted,
      "Documentation files missing from docs/README.md:\n  #{unlisted.join("\n  ")}"
  end

  test "no changelog entry is a paragraph" do
    # docs/delivery_history.md is exempt by construction: it is the long form, and it is frozen.
    overlong = changelog_entries.map { |line, entry| [ line, entry_words(entry) ] }
      .reject { |_line, count| count <= CHANGELOG_ENTRY_WORD_LIMIT }

    assert_empty overlong,
      "Changelog entries over #{CHANGELOG_ENTRY_WORD_LIMIT} words. An entry names the subject in " \
      "one or two sentences; the reasoning belongs in docs/delivery_history.md or in the document " \
      "that owns the subject:\n#{overlong.map { |line, count| "  line #{line}: #{count} words" }.join("\n")}"
  end

  private

  # Each top-level "- " bullet in the changelog as [line number, text], with its continuation lines
  # joined in. A dated entry is one bullet: it may wrap over several lines, and it is the bullet plus
  # what follows it that has to stay short.
  def changelog_entries
    @changelog_entries ||= begin
      entries = []
      Rails.root.join("CHANGELOG.md").read.split("\n").each_with_index do |line, index|
        if line.start_with?("- ")
          entries << [ index + 1, line ]
        elsif entries.any? && !line.strip.empty? && !line.start_with?("#")
          entries.last[1] = "#{entries.last[1]} #{line.strip}"
        end
      end
      entries
    end
  end

  # Words as a reader counts them: inline code, emphasis, and link syntax are punctuation around the
  # words, not words of their own.
  def entry_words(entry)
    entry.gsub(/[`*_\[\]()#|]/, "").split.size
  end

  def markdown_files
    @markdown_files ||= Dir.glob(DOCS_ROOT.join("**/*.md")).sort.map { |file| Pathname(file) }
  end

  def relative(file)
    Pathname(file).relative_path_from(Rails.root).to_s
  end

  def historical?(relative_path)
    HISTORICAL_GLOBS.any? { |glob| File.fnmatch?(glob, relative_path, File::FNM_PATHNAME) }
  end

  # Headings a document claims ownership of. A historical record is excluded: it is frozen, so
  # it cannot be the second source of a fact, and it must never be made to change.
  def headings(file)
    return [] if historical?(relative(file))

    all_headings(file)
  end

  # Every heading a document contains, historical or not. Anchor resolution needs these even for
  # historical files, because a living document may legitimately link into a frozen record.
  def all_headings(file)
    file.read.scan(/^#{'#'}{2,3} +(.+?) *$/).flatten
  end

  # Markdown links: [text](target) and [text](target#anchor), skipping http(s) and mailto.
  def markdown_links(file)
    file.read.scan(/\[[^\]]*\]\(([^)\s]+)\)/).flatten
  end

  def broken_links(file)
    markdown_links(file).filter_map do |target|
      next if target.start_with?("http", "mailto:")
      next if target.start_with?("#")

      path = target.split("#").first
      next if path.empty? # A same-document anchor, checked by the anchor test.

      resolved = File.expand_path(path, file.dirname)
      next if File.exist?(resolved)

      [ relative(file), target ]
    end
  end

  def broken_anchors(file)
    markdown_links(file).filter_map do |target|
      path, anchor = target.split("#", 2)
      next if anchor.nil? || anchor.empty?
      next if path.nil? || path.empty? # A same-document anchor.
      next if target.start_with?("http", "mailto:")

      resolved = File.expand_path(path, file.dirname)
      next unless File.exist?(resolved)

      slugs = all_headings(Pathname(resolved)).map { |heading| anchor_slug(heading) }
      next if slugs.include?(anchor)

      [ relative(file), target ]
    end
  end

  # GitHub's heading-to-anchor rule, which is what every Markdown viewer in this repo's docs
  # applies: lowercase, drop punctuation other than hyphens and underscores, spaces to hyphens.
  def anchor_slug(heading)
    heading.downcase.gsub(%r{[^\p{Alnum}\p{Space}\-_]}, "").strip.gsub(/\s/, "-")
  end
end
