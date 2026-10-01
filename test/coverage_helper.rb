# Coverage measurement for the Minitest suite. Required from `test/test_helper.rb`
# **before** `config/environment`, because SimpleCov only measures what is loaded
# after it starts. Everything Rails loads while booting is application code, so a
# start placed after the environment would report all of it as untested.
#
# The report is diagnostic first and a gate second. A line percentage says how much
# of the application executed, not whether the behavior that matters is covered:
# authorization, cross-universe scope, the JSON/HTML response contracts, and the
# failure paths are all things a high number can coexist with being untested. The
# threshold is set from a measured baseline with headroom rather than from an
# outside target, and it exists to notice a *drop*, not to reward adding assertions.
# `docs/development.md` owns the local command, the exclusions, and the limits.
require "simplecov"

# The measured baseline on 2026-10-01, with `bin/rails test` and eight workers:
# 94.59% line / 80.99% branch, which is the gated `CI=1` figure. Both floors sit a
# few points below that so an ordinary change does not trip them and an unrelated
# drop does. Raising them is a deliberate decision made with a fresh measurement,
# not something a commit should do by accident.
#
# The 2026-09-25 DataFactor report suggested 80%. Measured, that number is below
# this codebase's baseline and would never fail, so it is recorded rather than
# adopted; see `docs/adr/0006-data-factor-quality-guidance.md`.
MINIMUM_LINE_COVERAGE = 90
MINIMUM_BRANCH_COVERAGE = 75

# The threshold is a CI gate, so it is enforced where the whole suite runs and
# nowhere else. `bin/rails test test/models/section_test.rb` and
# `bin/rails test -n "/some_pattern/"` both measure a fraction of the application
# by design, and failing those would make the number a reason to avoid running a
# test. The project already uses `ENV["CI"]` to mean "this is CI" for eager
# loading, so the same variable decides this; `CI=1 bin/rails test` checks the
# gate locally with the same eager loading CI gets. The browser suite opts out of
# the gate in `test/application_system_test_case.rb`, because it is a smoke suite
# and its total is not comparable to this baseline.
COVERAGE_GATE = !ENV["CI"].to_s.empty?

SimpleCov.start do
  enable_coverage :branch

  # Only this application's own code. Gems, the schema, seeds, and the test suite
  # itself are not what a coverage number for this repository should measure.
  # `cover` also reports files that were never loaded, which is how a file nothing
  # requires shows up as 0% instead of silently not appearing.
  cover "app/{channels,controllers,helpers,jobs,mailers,models,services}/**/*.rb"
  cover "lib/**/*.rb"

  # Client-side code has its own runner and its own gate (`bun run test:js`). Ruby
  # here and JavaScript there means one number for two toolchains, and the
  # JavaScript half would always read as zero.
  skip "app/javascript"
  skip "app/assets"

  # `tmp/` is already git-ignored, so the HTML and JSON reports stay out of the
  # repository without a second ignore rule.
  coverage_dir "tmp/coverage"

  formats :html, :json

  # `parallelize(workers:)` forks one process per worker, and a forked process's
  # coverage never reaches the parent's unless SimpleCov attaches itself to the
  # fork. Without this the run passes and the report holds only the parent
  # process's own execution — a few percent, with nothing to explain it.
  merge_subprocesses true

  if COVERAGE_GATE
    coverage :line do
      minimum MINIMUM_LINE_COVERAGE
    end

    coverage :branch do
      minimum MINIMUM_BRANCH_COVERAGE
    end
  end
end

# A worker can take longer than the others on a saturated machine, and a worker
# that dies without writing its resultset would leave the merged total quietly
# partial. A partial total is not a coverage failure, so the longer timeout keeps
# a slow machine from producing one, and SimpleCov still warns if a worker really
# is missing. This is also why the gate lives in CI: there, one slow worker cannot
# turn a real suite into a passing-looking partial one.
SimpleCov.parallel_wait_timeout = 120
