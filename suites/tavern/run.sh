#!/bin/sh
# Runs the suite in the pinned image against the SUT on localhost:8280.
#   run.sh [pytest args]   e.g. run.sh -k test_08 --junitxml=report.xml
#   run.sh teardown        roll back a run that a killed session left open
set -eu
cd "$(dirname "$0")"
docker build -q -t bakeoff-tavern:3.7.2 . >/dev/null
entry=python
if [ "${1:-}" = teardown ]; then set -- -c 'import conftest; conftest.recover()'; else set -- -m pytest "$@"; fi
exec docker run --rm --network host -u "$(id -u):$(id -g)" --entrypoint "$entry" \
  -e AIDBOX_URL="${AIDBOX_URL:-http://localhost:8280}" \
  -v "$PWD:/suite" -v "$PWD/../../sut/fixtures/fixtures.json:/fixtures/fixtures.json:ro" \
  bakeoff-tavern:3.7.2 "$@"
