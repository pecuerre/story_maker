require "test_helper"

# Guards the documentation itself, because the docs are the input every other agent and the
# owner work from. A wrong duplicate is worse than a missing fact: an assistant that finds a
# confident, well-written, wrong paragraph acts on it, whereas an absent fact sends it to the
# code. These tests keep the documentation honest about itself, so drift is caught by the
# suite instead of by an agent discovering it mid-task.
class DocsTest < ActiveSupport::TestCase
  DOCS_ROOT = Rails.root.join("docs")
  # Historical records are deliberately frozen: an ADR states what was decided at the time, and
  # a resolved quirk states what used to be broken. Both are allowed to disagree with the code
  # now, so they are excluded from link and heading checks.
  HISTORICAL_GLOBS = [ "docs/adr/**/*.md", "docs/resolved_quirks.md" ].freeze

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

  private

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
