#!/bin/sh
# Build the pinned runner and run the suite against the bakeoff-sut stack.
#   ./run.sh              one run (setup, tests, teardown)
#   RUNS=2 ./run.sh       consecutive runs (case 15); stops at the first red one
#   ./run.sh -n 4         extra args go to pytest; -n runs the suite in parallel with xdist
#   ./run.sh teardown     close a run left open by a killed runner
set -eu
DIR=$(cd "$(dirname "$0")" && pwd)
docker build -q -t bakeoff-pytest "$DIR" >/dev/null
pytest() {
  docker run --rm --network bakeoff-sut_default -e AIDBOX_URL=http://aidbox:8080 \
    -v "$DIR/../../sut/fixtures/fixtures.json:/fixtures.json:ro" -v "$DIR/reports:/suite/reports" "$@"
}
if [ "${1:-}" = teardown ]; then
  pytest --entrypoint python bakeoff-pytest -c 'import aidbox; aidbox.close_open_run()'
  exit
fi
i=0
while [ "$i" -lt "${RUNS:-1}" ]; do
  i=$((i + 1))
  pytest bakeoff-pytest --junitxml="reports/junit-$i.xml" "$@"
done
