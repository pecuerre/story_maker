# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t universe_maker .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name universe_maker universe_maker

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# The base image is pinned by digest, with the tag kept beside it as the human-readable statement of
# what was pinned. A tag is a mutable name that a publisher can re-point; the digest is what makes the
# build reproducible, and this one is the multi-architecture OCI *index*, so amd64 (CI and the Kamal
# builder) and arm64 (a local `docker build` on Apple silicon) both resolve through it.
#
# There is no `ARG RUBY_VERSION` here any more: with a digest present the tag no longer selects
# anything, so an ARG beside it would be ignored silently. `test/deployment/pin_consistency_test.rb`
# asserts this version is the one in `mise.toml`, because a Ruby bump has to move the version and the
# digest together. Dependabot's `docker` ecosystem updates both.
FROM docker.io/library/ruby:4.0.0-slim@sha256:fe89c3e461b5258352ed5cbe0355fe239a0c7d0ca6c4d9fa22537b98d4432a6c AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips sqlite3 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems and the Bun-based CSS toolchain.
#
# Bun comes from its GitHub release archive, verified against the SHA-256 manifest that same release
# publishes, rather than from `curl … | bash` of a mutable install script. The architecture is read
# at build time so a local build on Apple silicon still gets an arm64 Bun, and the archive is stored
# under the name the manifest uses so `sha256sum --check` can verify it. A truncated or mismatched
# download fails here instead of part-way through a CSS build.
ARG BUN_VERSION=1.4.2
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libvips libyaml-dev pkg-config unzip && \
    case "$(uname -m)" in \
      x86_64) bun_archive=bun-linux-x64.zip ;; \
      aarch64|arm64) bun_archive=bun-linux-aarch64.zip ;; \
      *) echo "unsupported architecture $(uname -m) for the pinned Bun build" >&2; exit 1 ;; \
    esac && \
    bun_release="https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}" && \
    curl -fsSLo "/tmp/${bun_archive}" "${bun_release}/${bun_archive}" && \
    curl -fsSLo /tmp/SHASUMS256.txt "${bun_release}/SHASUMS256.txt" && \
    cd /tmp && \
    grep " ${bun_archive}\$" SHASUMS256.txt | sha256sum --check --strict - && \
    unzip -q "${bun_archive}" -d /tmp/bun && \
    install -m 0755 "/tmp/bun/${bun_archive%.zip}/bun" /usr/local/bin/bun && \
    cd / && \
    rm -rf /tmp/bun "/tmp/${bun_archive}" /tmp/SHASUMS256.txt && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY vendor/* ./vendor/
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Copy application code
COPY . .

# Install JavaScript dependencies from the committed lockfile
RUN bun install --frozen-lockfile

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
#
# `config/environments/production.rb` refuses to boot without APP_HOST, MAILER_FROM and
# SMTP_ADDRESS, and `assets:precompile` boots the production environment, so the build needs those
# three names even though nothing here contacts a mail server or serves a request. These are
# reserved `.invalid` defaults used only for this step: asset digests do not depend on them, and
# they are deliberately build arguments rather than image environment variables, so the running
# container still has to be given real values.
ARG APP_HOST=assets.universe-maker.invalid
ARG MAILER_FROM=no-reply@assets.universe-maker.invalid
ARG SMTP_ADDRESS=smtp.universe-maker.invalid

RUN SKIP_BUN_INSTALL=1 SECRET_KEY_BASE_DUMMY=1 \
    APP_HOST=$APP_HOST \
    MAILER_FROM=$MAILER_FROM \
    SMTP_ADDRESS=$SMTP_ADDRESS \
    ./bin/rails assets:precompile

# Drop the JavaScript build toolchain before the final stage copies this tree. Nothing at runtime
# needs it: the stylesheet, `bootstrap.bundle.min.js`, and the bootstrap-icons font are digested
# into `public/assets` by the precompile above, and the browser is served those copies through the
# import map and propshaft. Removing it here rather than in the final stage is the part that
# matters -- a later `rm -rf` would hide the files behind a layer without shrinking the image.
RUN rm -rf node_modules




# Final stage for app image
FROM base

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
