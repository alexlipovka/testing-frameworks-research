#!/bin/sh
# Runs the suite: shared fixture setup, cases/*.hurl and the case 8 matrix, teardown.
# RUNS=2 (default) is case 15: the second run must be green on the first one's leftovers.
#   ./run.sh [extra hurl args, e.g. --report-junit out/junit.xml]
set -eu
cd "$(dirname "$0")"
FIX=../../sut/fixtures/run.sh
export FIXTURES_VARS="$PWD/.vars"
URL=${AIDBOX_URL:-http://localhost:8280}
hurl() {
  docker run --rm --network host -u "$(id -u):$(id -g)" -v "$PWD:/s" -w /s \
    ghcr.io/orange-opensource/hurl:8.1.0 --variable "url=$URL" --variables-file .vars "$@"
}

trap '$FIX teardown' EXIT
for _ in $(seq "${RUNS:-2}"); do
  $FIX setup
  hurl --test "$@" cases/*.hurl
  grep -v '^#' matrix/table.txt | while read -r tok read search update enc; do
    hurl --test --variable "token=$(sed -n "s/^$tok=//p" .vars)" --variable "read_patient=$read" \
      --variable "search_patient=$search" --variable "update_patient=$update" \
      --variable "read_encounter=$enc" matrix/matrix.hurl || { echo "matrix row: $tok" >&2; exit 1; }
  done
  $FIX teardown
done
