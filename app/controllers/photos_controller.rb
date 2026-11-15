# Serves one stored photo's bytes under the Universe's read policy.
#
# **Active Storage's own URL is not an access check.** It is signed for the blob,
# not for the reader, so anyone holding it can fetch the image after their access
# to a private Universe is revoked or after they share it with somebody else. The
# framework's blob and disk routes are therefore not mounted
# (`config.active_storage.draw_routes` is `false`), and every photo in the
# application is fetched from this action instead.
#
# The route is inside the Universe scope, so `UniverseAuthorization` has already
# answered `:read` for `Current.universe` before this action runs: a guest may read
# a public Universe's photo, a member may read a private one, and everyone else is
# refused. The photo is then looked up through that Universe, so an id from
# another Universe is a 404 rather than a record this request may serve.
class PhotosController < ApplicationController
  allow_unauthenticated_access only: :show

  # A photo is not story-scoped, and resolving the remembered story would run a
  # story query and touch the remembered destination on every image request.
  skip_before_action :set_current_story, only: :show

  def show
    photo = Current.universe.photos.find(params[:id])

    # `no-store` rather than a cache lifetime: the browser may not keep a copy
    # that can be shown after the reader's access is revoked. A revoked member is
    # answered by the next request, and no intermediate proxy gets to hold the
    # image either.
    response.headers["Cache-Control"] = "private, no-store"
    send_data photo.file.download,
      filename: photo.file.filename.to_s,
      type: photo.file.blob.content_type,
      disposition: "inline"
  end
end
