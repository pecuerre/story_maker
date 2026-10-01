# Wire `Rails.error` to `ErrorTracking` so an unhandled exception, a failed job,
# and anything the application reports through `Rails.error` are recorded — in the
# log always, and to an external collector only when `ERROR_TRACKING_DSN` is set.
#
# The file is required rather than autoloaded because `config/initializers` runs
# before the main autoloader is set up, and `ErrorTracking.subscribe!` has to run
# at boot for a malformed DSN to be a boot failure.
require Rails.root.join("lib/error_tracking")

ErrorTracking.subscribe!
