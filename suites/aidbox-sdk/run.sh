#!/bin/sh
# Build the pinned runner and run the suite against the bakeoff-sut stack.
#   ./run.sh              one run; safe_db rolls back after every test, the session stamp after all
#   ./run.sh twice        two consecutive full runs (case 15); stops at the first red one
#   ./run.sh teardown     close a run left open by a killed runner
#   ./run.sh [pytest args]
set -eu
DIR=$(cd "$(dirname "$0")" && pwd)
docker build -q -t bakeoff-aidbox-sdk "$DIR" >/dev/null
mkdir -p "$DIR/reports"
suite() {
  docker run --rm --network bakeoff-sut_default --network-alias aidbox-sdk-suite \
    -u "$(id -u):$(id -g)" -e HOME=/tmp --env-file "$DIR/env" \
    -v "$DIR/reports:/suite/reports" "$@"
}
case "${1:-}" in
  teardown)
    suite --entrypoint python bakeoff-aidbox-sdk -m tests.run_stamp
    ;;
  twice)
    shift
    for i in 1 2; do
      suite bakeoff-aidbox-sdk --junitxml="reports/junit-$i.xml" "$@"
    done
    ;;
  *)
    suite bakeoff-aidbox-sdk --junitxml=reports/junit.xml "$@"
    ;;
esac
