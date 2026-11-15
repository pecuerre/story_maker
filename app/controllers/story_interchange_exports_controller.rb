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
class StoryInterchangeExportsController < ApplicationController
  allow_unauthenticated_access only: %i[ show ]

  before_action :set_story

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
