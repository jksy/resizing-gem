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

# Install gems into a named volume, so nothing is written to the bind-mounted
# workspace and a rebuild does not have to fetch them again.
ENV BUNDLE_PATH=/usr/local/bundle

RUN mkdir -p "${BUNDLE_PATH}" && chown -R vscode:vscode "${BUNDLE_PATH}"

# Ruby artifacts generated on the host must not leak in through the bind mount:
# vendor/ holds gems with native extensions built against the host's glibc,
# .bundle/config points BUNDLE_PATH at it, and .ruby-lsp/ records which gems the
# Ruby LSP extension has installed. compose.yaml keeps all three on their own
# volumes; creating the directories here gives those volumes the right owner.
RUN mkdir -p /workspaces/resizing-gem/vendor \
             /workspaces/resizing-gem/.bundle \
             /workspaces/resizing-gem/.ruby-lsp \
    && chown -R vscode:vscode /workspaces

# Bundler's global config, so that BUNDLE_PATH also applies to tools that
# compose their own bundle with a clean environment. The Ruby LSP extension
# builds one under .ruby-lsp/, which makes that directory bundler's app root,
# so a config in the workspace root would not be read for it.
RUN mkdir -p /home/vscode/.bundle \
    && printf '%s\n' '---' 'BUNDLE_PATH: "/usr/local/bundle"' \
        > /home/vscode/.bundle/config \
    && chown -R vscode:vscode /home/vscode/.bundle
