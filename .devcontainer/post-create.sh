#!/usr/bin/env bash
# Runs once after the dev container is created.
set -euo pipefail

echo "==> bundle install"
bundle install

echo "==> waiting for MySQL (${MYSQL_HOST}:${MYSQL_PORT})"
for _ in $(seq 1 60); do
  if mysqladmin ping \
      -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" \
      -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
      --silent > /dev/null 2>&1; then
    echo "MySQL is ready"
    break
  fi
  sleep 1
done

cat <<'MSG'

setup done.

  bundle exec rake test      # run the tests
  bundle exec rubocop        # run the linter
  bin/console                # interactive prompt

MSG
