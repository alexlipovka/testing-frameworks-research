#!/bin/sh
# Build the pinned runner and run the suite against the SUT on the host.
#   ./run.sh            one run
#   ./run.sh twice      two consecutive runs, both must pass (case 15)
#   ./run.sh teardown   roll back a run whose runner died (reports/open-run.json)
#   ./run.sh -- ARGS    extra Playwright args, e.g. -- tests/08-matrix.spec.ts
set -eu
cd "$(dirname "$0")"
docker build -q -t bakeoff-playwright:1.65.0 . >/dev/null
FIXTURES=$(cd ../../sut/fixtures && pwd)/fixtures.json
mkdir -p reports
docker_run() {
  docker run --rm --network host -u "$(id -u):$(id -g)" -e HOME=/tmp \
    -e AIDBOX_URL="${AIDBOX_URL:-http://localhost:8280}" -e FIXTURES_JSON=/fixtures.json \
    -v "$FIXTURES":/fixtures.json:ro -v "$PWD/reports":/suite/reports "$@"
}
once() { docker_run bakeoff-playwright:1.65.0 "$@"; }
case "${1:-}" in
  twice) shift; once "$@" && once "$@" ;;
  teardown) docker_run --entrypoint node bakeoff-playwright:1.65.0 lib/teardown.ts ;;
  --) shift; once "$@" ;;
  *) once "$@" ;;
esac
