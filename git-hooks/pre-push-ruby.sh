#!/bin/sh
# pre-push-ruby.sh
# Runs the same checks as CI (RuboCop and the test suite) before pushing.
# Called from git-hooks/pre-push. Aborts the push if any check fails.
#
# The checks run wherever the gems are installed: the current shell when it
# already has them (inside the devcontainer, or a host with `bundle install`
# done), otherwise the devcontainer started for this checkout.
#
#   PRE_PUSH_SKIP_TESTS=1 git push   # lint only, skip the test suite
#   git push --no-verify             # skip every check (not recommended)
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT" || exit 1

if bundle check >/dev/null 2>&1; then
  MODE=local
else
  # The devcontainer CLI and VS Code label the container with the host folder it
  # was started for. Looking it up by that label never picks a container started
  # for another worktree, which mounts other files: the checks would then pass
  # or fail for code that is not the one being pushed.
  CONTAINER="$(docker ps --quiet --filter "label=devcontainer.local_folder=$ROOT" 2>/dev/null | head -n 1)"
  if [ -z "$CONTAINER" ]; then
    echo "No environment with the gems installed was found."
    echo "No devcontainer is running for $ROOT."
    echo "Run 'devcontainer up --workspace-folder .' (or 'bundle install') first."
    echo "To skip this check (not recommended): git push --no-verify"
    exit 1
  fi
  MODE=devcontainer
fi

run() {
  case "$MODE" in
    local)        bundle exec "$@" ;;
    # User and folder as in .devcontainer/devcontainer.json (remoteUser, workspaceFolder)
    devcontainer) docker exec -u vscode -w /workspaces/resizing-gem "$CONTAINER" bundle exec "$@" ;;
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
