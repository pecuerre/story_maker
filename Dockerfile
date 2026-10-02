# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t universe_maker .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name universe_maker universe_maker

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.10
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

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

# Install packages needed to build gems and the Bun-based CSS toolchain
ARG BUN_VERSION=1.4.2
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libvips libyaml-dev pkg-config unzip && \
    curl -fsSL https://bun.sh/install | bash -s "bun-v${BUN_VERSION}" && \
    ln -s /root/.bun/bin/bun /usr/local/bin/bun && \
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
