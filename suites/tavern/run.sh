#!/bin/sh
# Runs the suite in the pinned image against the SUT on localhost:8280.
#   run.sh [pytest args]   e.g. run.sh -n 4 for xdist parallel, run.sh --junitxml=report.xml
#   run.sh twice [args]    case 15: two consecutive runs, both green
#   run.sh teardown        roll back a run that a killed session left open
set -eu
cd "$(dirname "$0")"
docker build -q -t bakeoff-tavern:3.7.2 . >/dev/null
run() {
  docker run --rm --network host -u "$(id -u):$(id -g)" --entrypoint python \
    -e AIDBOX_URL="${AIDBOX_URL:-http://localhost:8280}" \
    -v "$PWD:/suite" -v "$PWD/../../sut/fixtures/fixtures.json:/fixtures/fixtures.json:ro" \
    bakeoff-tavern:3.7.2 "$@"
}
case "${1:-}" in
  teardown) run -c 'import conftest; conftest.recover()' ;;
  twice) shift; run -m pytest "$@" && run -m pytest "$@" ;;
  *) run -m pytest "$@" ;;
esac
