module StoryInterchange
  # One record type an import can write.
  #
  # A slice is small on purpose: it declares the name the import page shows, the
  # validator count it will write, and the record kind it owns, and it implements
  # `#call` to write those records from the report. Adding a record type is a
  # subclass plus one entry in `Importers::ALL`; the task and the page read that
  # list and need no edit.
  #
  # A profile slice — a record built from frontmatter and `##` sections — declares
  # its section mapping once here instead of in `#call`. `field_for` resolves a
  # heading to a column, `resolve_references` turns a `[[slug]]` into the name of a
  # record this run writes, and `reported` lists everything the slice deliberately
  # leaves behind so the preview says so before the run rather than only after.
  #
  # A profile value may be a column name or, for a section the app splits into
  # several answers, an ordered label map. `Sensory` writes the five `sensory_*`
  # answers: each labelled list item fills the answer its label names, several
  # labels may share one item, and prose with no recognized label fills the first
  # answer of the group so it is never dropped.
  #
  # `Outcome` is the small shared answer a slice returns: how many records it
  # wrote, and the source items it deliberately did not write. A slice reports
  # those instead of dropping them, because the layout may carry more than the app
  # knows and the operator should see what was left behind.
  class Importer
    Outcome = Data.define(:label_key, :created, :skipped) do
      def skipped? = skipped.any?
    end

    class << self
      # Declares the slice: `label_key` is an I18n key (never a translated string,
      # which would freeze one language at class load), `count` is the key in
      # `Report#counts` this slice writes, and `kind` is the `Report::Entity` kind
      # it reads. `profile` maps a normalized section heading to a column,
      # `heading_prefixes` catches headings that only differ in their tail (the
      # source writes "Lies about (to herself)" and "Lies about (to himself)"), and
      # `reported_keys` names frontmatter keys the application has no column for.
      def slice(label_key:, count:, kind: nil, profile: {}, heading_prefixes: {}, reported_keys: [])
        @label_key = label_key
        @count = count
        @kind = kind
        @profile = profile
        @heading_prefixes = heading_prefixes
        @reported_keys = reported_keys
      end

      attr_reader :label_key, :count, :kind, :profile, :heading_prefixes, :reported_keys

      # What the validator found for this slice, shown before anything is written.
      def preview(report)
        report.counts[count]
      end

      # Source items this slice will report rather than write. The default is
      # nothing; a slice that deliberately leaves a source record behind overrides
      # it, so the preview says so before the run rather than only after.
      def reported(report)
        return [] if kind.nil?

        report.entities(kind).flat_map { |entity| reported_entries(report, entity) }
      end

      # The column a source heading writes, or nil when no profile answer owns it.
      def field_for(heading)
        key = heading.to_s.downcase.squish
        profile[key] || heading_prefixes.find { |prefix, _field| key.start_with?(prefix) }&.last
      end

      # A `[[slug]]` becomes the name of the record this run writes for that slug,
      # so a profile answer reads as prose rather than as source syntax. A
      # reference to a record no slice writes (a Location before its slice, a
      # canon rule, a backlog id) is left exactly as written; `reported` names the
      # entity refs among them.
      def resolve_references(report, text)
        text.to_s.gsub(Document::REFERENCE) do
          target = Regexp.last_match(1).strip
          entity = report.entity(target)

          entity && Importers.written?(entity.kind) ? entity.name : Regexp.last_match(0)
        end
      end

      private
        # Everything this entity carries that no column or section target owns:
        # the preamble block, an unmapped section, a frontmatter key with no
        # column, and a `[[slug]]` whose record kind has no slice yet.
        def reported_entries(report, entity)
          entries = []
          entries << "#{entity.slug}: introduction" if entity.introduction.present?

          entity.sections.each do |section|
            entries << "#{entity.slug}: #{section.heading}" unless field_for(section.heading)
          end

          reported_keys.each do |key|
            entries << "#{entity.slug}: #{key}" if entity.frontmatter[key].present?
          end

          entries.concat(unresolved_references(report, entity))
        end

        def unresolved_references(report, entity)
          written_bodies(entity).flat_map do |body|
            body.scan(Document::REFERENCE).flatten.map(&:strip).uniq.filter_map do |target|
              "#{entity.slug}: [[#{target}]]" if unresolved?(report, target)
            end
          end.uniq
        end

        def written_bodies(entity)
          entity.sections.filter_map { |section| section.body if field_for(section.heading) }
        end

        def unresolved?(report, target)
          return false unless target.match?(Validator::SLUG)
          return false if Validator::PLACEHOLDER_REFERENCES.include?(target)

          entity = report.entity(target)
          entity.nil? || !Importers.written?(entity.kind)
        end
    end

    def initialize(report:, universe:)
      @report = report
      @universe = universe
    end

    def label_key
      self.class.label_key
    end

    # Writes every record this slice owns and returns an `Outcome`. Raising is a
    # refusal: the import's transaction rolls the whole run back.
    def call
      raise NotImplementedError, "#{self.class} must implement #call"
    end

    private
      attr_reader :report, :universe

      # A list item whose label names the profile answer it fills:
      # `- Sight: a gate taller than the wall.` The label is stripped, the text is
      # kept as written, and an indented continuation line stays with its item.
      GROUP_ITEM = /\A[ \t]*(?:[-*]|\d+\.)[ \t]+([^:\n]{1,60}):[ \t]*(.*)\z/

      # The shared body of a profile slice: one record per parsed entity, built
      # from the frontmatter and the sections `field_for` maps.
      def write_entities(record_class)
        created = report.entities(self.class.kind).map do |entity|
          record_class.create!(**attributes_for(entity))
        end

        Outcome.new(label_key: label_key, created: created.size, skipped: self.class.reported(report))
      end

      # What every record of this slice carries besides its profile answers. A
      # Story-owned record overrides this to name its Story instead of the
      # Universe.
      def record_attributes(entity)
        { name: entity.name, slug: entity.slug, universe: universe }
      end

      def attributes_for(entity)
        entity.sections.each_with_object(record_attributes(entity)) do |section, attributes|
          field = self.class.field_for(section.heading)
          next unless field

          if field.is_a?(Hash)
            attributes.merge!(grouped_attributes(field, section.body))
          else
            attributes[field] = self.class.resolve_references(report, section.body)
          end
        end
      end

      # Splits one section into the answers its ordered label map declares. The
      # first entry is the fallback: text whose label names no answer is written
      # there rather than dropped.
      def grouped_attributes(fields, body)
        attributes = {}

        grouped_items(body).each do |label, text|
          text = self.class.resolve_references(report, text)
          next if text.blank?

          targets = label ? label_fields(fields, label) : []
          targets = [ fields.values.first ] if targets.empty?
          targets.each { |field| append_answer(attributes, field, text) }
        end

        attributes
      end

      # `[label, text]` pairs in source order; a plain paragraph is one pair with
      # no label.
      def grouped_items(body)
        items = []
        blank = false

        body.each_line do |line|
          stripped = line.chomp.strip
          if stripped.empty?
            blank = true
            next
          end

          if (match = GROUP_ITEM.match(line.chomp))
            items << [ match[1].strip, +match[2] ]
          elsif items.any? && !blank && line.match?(/\A[ \t]+/)
            items.last.last << "\n" << stripped
          else
            items << [ nil, +stripped ]
          end

          blank = false
        end

        items.map { |label, text| [ label, text.strip ] }.reject { |_label, text| text.empty? }
      end

      # Every answer a label names. A label may name several (`Touch / smell`),
      # and a word that names none (`gravity`) is ignored. A singular label still
      # names a plural answer (`Point of interest`), so a trailing `s` on the
      # answer's own label is optional.
      def label_fields(fields, label)
        words = label.downcase.split(%r{[/,]}).map(&:strip)
        fields.filter_map do |fragment, field|
          field if words.any? { |word| label_matches?(word, fragment) }
        end.uniq
      end

      def label_matches?(word, fragment)
        word.include?(fragment) || word.include?(fragment.delete_suffix("s"))
      end

      def append_answer(attributes, field, text)
        attributes[field] = [ attributes[field], text ].compact_blank.join("\n\n")
      end
  end
end
