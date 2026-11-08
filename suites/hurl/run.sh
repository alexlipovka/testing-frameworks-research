#!/bin/sh
# Runs the suite: shared fixture setup, cases/*.hurl and the generated case 8 matrix, teardown.
# RUNS=2 (default) is case 15: the second run must be green on the first one's leftovers.
# ./run.sh [hurl args], or ./run.sh teardown to close a run left open by a killed runner (.vars).
set -eu
cd "$(dirname "$0")"
FIX=../../sut/fixtures/run.sh
export FIXTURES_VARS="$PWD/.vars"
URL=${AIDBOX_URL:-http://localhost:8280}
hurl() {
  docker run --rm --network host -u "$(id -u):$(id -g)" -v "$PWD:/s" -w /s \
    ghcr.io/orange-opensource/hurl:8.1.0 --variable "url=$URL" --variables-file .vars "$@"
}

if [ "${1:-}" = teardown ]; then exec $FIX teardown; fi

[ ! -f .vars ] || { echo "a run is open (.vars): ./run.sh teardown first" >&2; exit 1; }
rm -rf matrix/.gen && mkdir matrix/.gen
awk -v out=matrix/.gen -f matrix/gen.awk matrix/table.txt
trap '$FIX teardown' EXIT
for _ in $(seq "${RUNS:-2}"); do
  $FIX setup
  # long: a failed decision prints the debug dump (user, request, policy ids, SQL errors).
  hurl --test --error-format long --continue-on-error "$@" cases/*.hurl matrix/.gen/*.hurl
  $FIX teardown
done
