# Debian variant of the base image (bookworm / bullseye)
ARG VARIANT=bookworm
FROM mcr.microsoft.com/devcontainers/base:${VARIANT}

# Ruby installed and set as the rbenv global version. Matches .ruby-version.
# Other versions can be installed from inside the container with `rbenv install`.
ARG RUBY_VERSION=3.1.7

# Build dependencies for ruby-build, plus what the mysql2 gem needs.
# The MySQL packages match .github/workflows/test.yml.
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        autoconf \
        bison \
        build-essential \
        libffi-dev \
        libgdbm-dev \
        libncurses-dev \
        libreadline-dev \
        libssl-dev \
        libyaml-dev \
        uuid-dev \
        zlib1g-dev \
        default-libmysqlclient-dev \
        default-mysql-client \
        pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV RBENV_ROOT=/usr/local/rbenv
ENV PATH=${RBENV_ROOT}/shims:${RBENV_ROOT}/bin:${PATH}

# rbenv and ruby-build. RBENV_ROOT is owned by vscode so that `rbenv install`
# works from inside the container without sudo.
RUN git clone --depth 1 https://github.com/rbenv/rbenv.git "${RBENV_ROOT}" \
    && git clone --depth 1 https://github.com/rbenv/ruby-build.git "${RBENV_ROOT}/plugins/ruby-build" \
    && printf '%s\n' \
        'export RBENV_ROOT=/usr/local/rbenv' \
        'export PATH="$RBENV_ROOT/shims:$RBENV_ROOT/bin:$PATH"' \
        'eval "$(rbenv init -)"' \
        > /etc/profile.d/rbenv.sh

RUN rbenv install "${RUBY_VERSION}" \
    && rbenv global "${RUBY_VERSION}" \
    && gem install bundler \
    && rbenv rehash \
    && chown -R vscode:vscode "${RBENV_ROOT}"

# Install gems into a named volume so the host's vendor/ directory and
# .bundle/config (BUNDLE_PATH: vendor) are left untouched. BUNDLE_APP_CONFIG
# makes bundler ignore the workspace .bundle/config.
ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_APP_CONFIG=/usr/local/bundle

RUN mkdir -p "${BUNDLE_PATH}" && chown -R vscode:vscode "${BUNDLE_PATH}"

# The Ruby LSP extension generates .ruby-lsp/ in the workspace and records there
# which gems it has installed. A copy generated on the host would point at gems
# this container does not have, so compose.yaml keeps it on its own volume.
# Creating the directory here gives that volume the right owner.
RUN mkdir -p /workspaces/resizing-gem/.ruby-lsp \
    && chown -R vscode:vscode /workspaces
