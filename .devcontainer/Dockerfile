# The Ruby version is selected by build.args.VARIANT in .devcontainer/compose.yaml
# e.g. 1-3.1-bookworm / 1-3.2-bookworm / 1-3.3-bookworm / 1-3.4-bookworm
ARG VARIANT=1-3.1-bookworm
FROM mcr.microsoft.com/devcontainers/ruby:${VARIANT}

# The yarn apt repository bundled with the base image cannot be verified and
# makes apt-get update fail, so drop it (this project does not use yarn).
# The packages below match .github/workflows/test.yml.
RUN rm -f /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        default-libmysqlclient-dev \
        default-mysql-client \
        libyaml-dev \
        pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install gems into a named volume so the host's vendor/ directory and
# .bundle/config (BUNDLE_PATH: vendor) are left untouched. BUNDLE_APP_CONFIG
# makes bundler ignore the workspace .bundle/config.
ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_APP_CONFIG=/usr/local/bundle

RUN mkdir -p "${BUNDLE_PATH}" && chown -R vscode:vscode "${BUNDLE_PATH}"

# A leftover .ruby-version on the host (it is gitignored) makes rvm warn with
# "Required ruby-x.y.z is not installed". Always use the Ruby from the image.
RUN echo 'rvm_project_rvmrc=0' >> /etc/rvmrc
