# The two form fields a photo-capable editor posts, as one list.
#
# Eighteen controllers can carry a photo, and none of them should spell the
# parameter names out again. Both are virtual attributes on `HasPhoto`, not
# columns: `photo_data` is the square the author cropped and `remove_photo`
# clears the reference. Neither is ever a photo id, which is what makes a
# cross-universe photo impossible to assign from a request at all.
module PhotoParams
  extend ActiveSupport::Concern

  PHOTO_PARAMS = [ :photo_data, :remove_photo ].freeze

  private
    def photo_params
      PHOTO_PARAMS
    end
end
