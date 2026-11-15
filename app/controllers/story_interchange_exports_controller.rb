# The Story export page's directory download.
#
# It is a separate controller so its action is a `show`: the shared universe
# authorization grants `:read` to a `show` on a public universe, which is the
# access the Story page and the printable manuscript already have.
#
# **The download is Universe-wide even though the page is Story-scoped.** A
# story-interchange source describes one Universe and its Stories, and the
# importer replaces a Universe, so a Story-only slice would not be the same
# format. The Story resolves the request's Universe, exactly as the export page
# does, and the archive reads that Universe.
#
# The download is a GET that writes nothing. It assembles a `.tar.gz` in memory
# from `StoryInterchange::Export`; nothing is copied into the repository. When
# the export refuses because ordinary Scene prose cannot be written as a valid
# block, the request is sent back to the export page with the Scene and line
# named instead of returning an archive the import would reject.
#
# **Assembling the whole archive is the expensive part**, and a public Universe
# lets a guest ask for it, so the `show` action carries a per-client limit. The
# counter is per signed-in account and per address otherwise, so one client
# cannot assemble a growing Universe repeatedly while an address a team shares
# is not one budget for every signed-in member behind it.
class StoryInterchangeExportsController < ApplicationController
  # Five downloads in five minutes: an author downloads the source to import
  # it elsewhere, so a handful in one sitting is ordinary and a loop is not.
  DOWNLOAD_LIMIT = 5
  DOWNLOAD_WINDOW = 5.minutes

  allow_unauthenticated_access only: %i[ show ]

  before_action :set_story

  # Declared after `set_story` so the refusal can send the reader back to the
  # page the archive is offered on, and after the application's own callbacks
  # so a request that is not permitted never spends a counter.
  rate_limit to: DOWNLOAD_LIMIT, within: DOWNLOAD_WINDOW, only: :show,
    by: -> { Current.user ? "user:#{Current.user.id}" : "ip:#{request.remote_ip}" },
    with: -> { redirect_to universe_story_export_path(story_id: @story), alert: t("errors.rate_limited") }

  # GET /u/:universe_slug/s/:story_id/export/interchange
  def show
    export = StoryInterchange::Export.new(Current.universe)

    response.headers["Cache-Control"] = "no-store"
    send_data export.to_s,
      filename: export.filename,
      type: "application/gzip",
      disposition: "attachment"
  rescue StoryInterchange::Export::Unrepresentable => refusal
    # A source that would not import is not a download, so the author is sent
    # back to the page that offers it with the Scene and line to change.
    redirect_to universe_story_export_path(story_id: @story),
      alert: refusal_message(refusal)
  end

  private
    def refusal_message(refusal)
      first = refusal.problems.first

      t("story_exports.interchange.unrepresentable.#{first.reason}",
        count: refusal.problems.size,
        scene: first.scene,
        line: first.line,
        text: first.text.to_s.truncate(60))
    end
end
