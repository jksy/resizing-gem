#!/bin/sh
# pre-push-ruby.sh
# Runs the same checks as CI (RuboCop and the test suite) before pushing.
# Called from git-hooks/pre-push. Aborts the push if any check fails.
#
# The checks run wherever the gems are installed: the current shell when it
# already has them (inside the devcontainer, or a host with `bundle install`
# done), otherwise the devcontainer via its CLI or docker compose.
#
#   PRE_PUSH_SKIP_TESTS=1 git push   # lint only, skip the test suite
#   git push --no-verify             # skip every check (not recommended)
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT" || exit 1

if bundle check >/dev/null 2>&1; then
  MODE=local
elif command -v devcontainer >/dev/null 2>&1; then
  MODE=devcontainer
elif docker compose -f .devcontainer/compose.yaml ps --status running --quiet app 2>/dev/null | grep -q .; then
  MODE=compose
else
  echo "No environment with the gems installed was found."
  echo "Run 'devcontainer up --workspace-folder .' (or 'bundle install') first."
  echo "To skip this check (not recommended): git push --no-verify"
  exit 1
fi

run() {
  case "$MODE" in
    local)        bundle exec "$@" ;;
    devcontainer) devcontainer exec --workspace-folder "$ROOT" bundle exec "$@" ;;
    compose)      docker compose -f .devcontainer/compose.yaml exec -T app bundle exec "$@" ;;
  esac
}

if [ -n "${PRE_PUSH_SKIP_TESTS:-}" ]; then
  echo "Running RuboCop ($MODE)..."
  run rake rubocop
else
  echo "Running RuboCop and tests ($MODE)..."
  run rake ci
fi

if [ $? -ne 0 ]; then
  echo "Pre-push checks failed. Push aborted."
  echo "To skip this check (not recommended): git push --no-verify"
  exit 1
fi
