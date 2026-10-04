# Writing one draft's remembered changes, for whichever of the two actions is doing it.
#
# Two callers now run a draft through `DraftApplier`: the author pressing **Apply
# changes** on their own draft, and a reviewer pressing **Approve** on somebody else's
# submission. Everything they have to agree about is here, because each of those things is
# a question asked once and answered twice — and an answer that differed by caller would
# be a second answer about the same records:
#
# * **What is in conflict**, asked on *this* request rather than remembered from the last
#   one, so the conflicts the reader is asked about are the ones this run would otherwise
#   skip.
# * **What the request answered**, which is a security-relevant reading rather than a
#   formatting one: an answer is an instruction to write over somebody else's record and it
#   arrives in request parameters. The controller drops any value that is not one of
#   `DraftApplier::ANSWERS`, the applier drops any answer that is not for a change it is
#   actually applying, and the answers are kept only for conflicts found on *this* request.
#   A hidden field carrying yesterday's choice for a change that no longer conflicts is an
#   answer to a question nobody asked, and the applier would treat it as an instruction to
#   overwrite a record that is perfectly fine. Two controllers each spelling that out is how
#   the second one gets it subtly wrong.
# * **What the run did**, as the flash that follows it, read from the applier's own `Result`
#   and recounted by neither.
#
# Only the rendering is left to the caller: the author's conflicts page and a reviewer's
# say different things in their headers and post back to their own action, while the rows
# themselves are one partial (`drafts/_conflict`) and one vocabulary.
module AppliesDrafts
  extend ActiveSupport::Concern

  private
    # The conflicts a run would have to be told about.
    def draft_conflicts(draft)
      DraftConflictDetector.new(draft).conflicts
    end

    # The answers this request carries, keyed by change id and valued with one of
    # `DraftApplier::ANSWERS`.
    #
    # A missing `resolutions` param is an empty list rather than an error, and anything
    # that is not a plain hash is dropped whole: an answer is an instruction to write over
    # somebody else's record, so it is read from a shape this application produced rather
    # than from whatever arrived.
    def submitted_answers
      raw = params[:resolutions]
      return {} unless raw.respond_to?(:to_unsafe_h)

      raw.to_unsafe_h.each_with_object({}) do |(change_id, answer), answers|
        answers[change_id.to_s] = answer.to_s if DraftApplier::ANSWERS.include?(answer.to_s)
      end
    end

    def answered_all?(conflicts, answers)
      conflicts.all? { |conflict| answers.key?(conflict.change.id.to_s) }
    end

    # Show the conflicts instead of writing them. `template` is the only thing that
    # differs between the two callers: the rows, the answers, and the status are one
    # thing, because a resolution page that rendered a different set of questions per
    # caller would be two answers to the same conflict.
    def show_conflicts(conflicts, answers, template: :conflicts)
      @conflicts = conflicts
      @answers = answers.slice(*conflicts.map { |conflict| conflict.change.id.to_s })

      render template, status: :unprocessable_content
    end

    # What an apply did, as the flash that follows it: one or two sentences — what was
    # written, then what was chosen to leave alone. They stay separate because they are
    # separate outcomes: a change dropped on purpose was not skipped, is not in `skipped`,
    # and does not make the run partial, so folding it into either count would report the
    # run as failed when the reviewer simply decided.
    def draft_apply_notice(result)
      sentences = []
      sentences << draft_apply_progress_sentence(result) unless draft_apply_only_keeping?(result)
      sentences << t("drafts.flash.kept_theirs", count: result.kept_count) if result.kept_count.positive?

      sentences.join(" ")
    end

    # An apply where nothing was written because every conflict was answered
    # `"theirs"` has no progress to report. "0 remembered changes are now live"
    # answers a question the reader did not ask and buries the one they did, so the
    # kept sentence stands alone — unless something was also refused, which is news the
    # partial sentence has to carry either way.
    def draft_apply_only_keeping?(result)
      result.complete? && result.applied_count.zero? && result.kept_count.positive?
    end

    # What an apply did, in one sentence. A draft applied whole and a draft where some
    # changes could not be written are different sentences because they are different
    # outcomes, and the second one says that the changes are still listed rather than
    # implying they are gone.
    def draft_apply_progress_sentence(result)
      return t("drafts.flash.applied", count: result.applied_count) if result.complete?

      t("drafts.flash.partially_applied", applied: result.applied_count, skipped: result.skipped_count)
    end
end
