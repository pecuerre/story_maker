# The platform-admin story-interchange import.
#
# **Both actions ask for `:manage` on `StoryInterchange::Import`**, the same
# platform-level question the universe creation limit asks. An import creates a
# Universe and replaces the one its source directory names, so it is not a
# read or a write inside any universe: there is no universe to borrow an admin
# from. A guest is sent to sign in; a signed-in account without the platform flag
# receives `403`.
#
# The page never accepts a path from the browser. It offers the folders directly
# under `STORY_INTERCHANGE_IMPORT_ROOT`, and `StoryInterchange::ImportRoot` turns a
# chosen name into a path only when it is a real child of that root. The write is
# a `POST` behind a checkbox that says what is lost; the controller refuses the
# request when the box is absent, and the import service refuses it again when
# the target Universe has open drafts or members other than the importer.
class StoryInterchangeImportsController < ApplicationController
  def show
    authorize! :manage, StoryInterchange::Import
    load_source
    flash.now[:alert] = t("imports.flash.unknown_source") if @source && @source_path.nil?
  end

  def create
    authorize! :manage, StoryInterchange::Import
    load_source

    return redirect_to import_path, alert: t("imports.flash.source_required") if @source.nil?
    return refuse(t("imports.flash.unknown_source")) if @source_path.nil?
    return refuse(t("imports.flash.unconfirmed")) unless confirmed?
    return refuse(t("imports.flash.blocked")) unless @plan.importable?

    result = @import.call

    redirect_to universe_path(result.universe),
      notice: outcome_message(result), status: :see_other
  rescue StoryInterchange::Import::Refused => refusal
    # The state changed between the preview and the write. The plan the service
    # refused is the one to show, so the page names what it found now.
    @plan = refusal.plan
    refuse(t("imports.flash.blocked"))
  end

  private
    def load_source
      @import_root = StoryInterchange.import_root
      @source = params[:source].to_s.presence
      @source_path = @source && @import_root.path_for(@source)
      @import = @source_path && StoryInterchange::Import.new(@source_path, owner: Current.user)
      @plan = @import&.plan
    end

    def confirmed?
      params[:confirm] == "1"
    end

    def refuse(message)
      flash.now[:alert] = message
      render :show, status: :unprocessable_content
    end

    # One sentence per slice: what was written, and the source ids the slice
    # deliberately reported instead of writing. The task prints the same answer
    # from the same `Outcome`, so the two surfaces cannot describe the run
    # differently.
    def outcome_message(result)
      sentences = [ t("imports.flash.imported", name: result.universe.name) ]

      result.outcomes.each do |outcome|
        sentences << t("imports.flash.written", label: t(outcome.label_key), count: outcome.created)
        next unless outcome.skipped?

        sentences << t("imports.flash.skipped", label: t(outcome.label_key),
          count: outcome.skipped.size, ids: outcome.skipped.to_sentence)
      end

      sentences.to_sentence
    end
end
