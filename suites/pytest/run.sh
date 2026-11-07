#!/bin/sh
# Build the pinned runner and run the suite against the bakeoff-sut stack.
#   ./run.sh              one run (setup, tests, teardown)
#   RUNS=2 ./run.sh       consecutive runs (case 15); stops at the first red one
#   ./run.sh -k matrix    extra args go to pytest
set -eu
DIR=$(cd "$(dirname "$0")" && pwd)
docker build -q -t bakeoff-pytest "$DIR" >/dev/null
i=0
while [ "$i" -lt "${RUNS:-1}" ]; do
  i=$((i + 1))
  docker run --rm --network bakeoff-sut_default \
    -e AIDBOX_URL=http://aidbox:8080 \
    -v "$DIR/../../sut/fixtures/fixtures.json:/fixtures.json:ro" \
    -v "$DIR/reports:/suite/reports" \
    bakeoff-pytest --junitxml="reports/junit-$i.xml" "$@"
done
