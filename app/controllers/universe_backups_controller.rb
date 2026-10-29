# The admin-only universe backup.
#
# **Both actions ask for `admin`** through `UniverseAuthorization`, the same line
# memberships, the reviewer queue, and the change history use. A backup is not a
# read of one page: it carries the whole core dataset, including private draft
# material that the sensitive slice will add later. A plain writer has no business
# holding that copy, even in a public universe.
#
# The download is a GET that writes nothing. It assembles a `.tar.gz` in memory
# from `UniverseBackup::Archive`; the archive is a read of the database and Active
# Storage, and its restore is a separate destructive command that does not exist
# yet.
class UniverseBackupsController < ApplicationController
  def show
    @universe = Current.universe
  end

  def download
    archive = UniverseBackup::Archive.new(Current.universe)

    response.headers["Cache-Control"] = "no-store"
    send_data archive.to_s,
      filename: archive.filename,
      type: "application/gzip",
      disposition: "attachment"
  end
end
