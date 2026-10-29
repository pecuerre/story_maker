module StoryInterchange
  # Writes a validated source into ordinary records, replacing the one Universe
  # the source is named after.
  #
  # The source is never copied or modified. A run validates the tree, checks that
  # replacing the target Universe is safe, soft-deletes it when it exists, creates
  # a fresh Universe with the derived slug and name, and asks every registered
  # slice to write its records — all in one transaction, so a refused or failed
  # slice leaves the database as it was.
  #
  # **Replacing is a soft delete, not a hard one.** This application's own delete
  # is `SoftDeletable#soft_delete`, and a hard delete would leave soft-deleted
  # child rows whose foreign keys still name the old Universe. The old rows are
  # therefore kept but hidden, exactly as the app's delete keeps them, while the
  # new Universe occupies the same slug. There is no restore path for a Universe,
  # which is why the confirmation still says the app's records for it are lost.
  #
  # The confirmation itself belongs to the caller — the page's checkbox and the
  # task's environment variable — because this object is also the entry point a
  # test calls. The safety check does not: an existing Universe with open drafts
  # or a member other than the importer is refused here, so no caller can skip it.
  class Import
    # Raised when the plan cannot be written. It carries the plan so the caller
    # can render exactly what it refused and why, instead of re-validating.
    class Refused < StandardError
      attr_reader :plan

      def initialize(plan)
        @plan = plan
        super("the source cannot be imported")
      end
    end

    Result = Data.define(:universe, :replaced, :outcomes)

    # What a run would do, computed before anything is written. The page shows
    # this as its preview; `call` builds the same plan and refuses it if it is
    # not importable.
    Plan = Data.define(:report, :existing_universe, :open_drafts, :other_members) do
      def slug = report.universe_slug
      def name = report.universe_name
      def existing? = existing_universe.present?

      # The validator found no error.
      def valid? = report.valid?

      # Replacing a Universe is safe when nobody else has unfinished work in it:
      # no open draft, and no member other than the importer. The owner counts as
      # a member, so an existing Universe owned by somebody else is refused too.
      def safe? = open_drafts.empty? && other_members.empty?

      def importable? = valid? && safe?

      def slices = Importers::ALL
    end

    def initialize(path, owner:)
      raise ArgumentError, "an import needs an owner" if owner.nil?

      @path = File.expand_path(path)
      @owner = owner
    end

    def plan
      report = StoryInterchange.validate(@path)
      existing = report.universe_slug && Universe.find_by(slug: report.universe_slug)

      Plan.new(
        report: report,
        existing_universe: existing,
        open_drafts: existing ? existing.drafts.open.order(:id).to_a : [],
        other_members: existing ? existing.members.where.not(id: @owner.id).order(:name).to_a : []
      )
    end

    def call
      plan = self.plan
      raise Refused, plan unless plan.importable?

      result = nil

      Universe.transaction do
        plan.existing_universe&.soft_delete
        universe = create_universe(plan)
        outcomes = Importers::ALL.map { |slice| slice.new(report: plan.report, universe:).call }

        result = Result.new(universe:, replaced: plan.existing?, outcomes:)
      end

      result
    end

    private
      # The source carries no privacy or collaboration setting, so a fresh
      # Universe takes the model's defaults. A replaced one keeps the settings it
      # had: silently publishing a private Universe, or turning a draft-based one
      # into a direct one, is not part of an import.
      def create_universe(plan)
        Universe.create!(
          name: plan.name,
          slug: plan.slug,
          owner: @owner,
          private: plan.existing_universe ? plan.existing_universe.private? : false,
          collaboration_mode: plan.existing_universe&.collaboration_mode || "direct"
        )
      end
  end
end
