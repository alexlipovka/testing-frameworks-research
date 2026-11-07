#!/bin/sh
# mutants.sh [MUTANT...]: every mutant (default all) x every suite in native mode:
# baseline run, mutant run twice, decision-ablated copy once -> results/mutants.csv,
# logs in results/mutants/<mutant>/.
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
. "$REPO/bench/lib.sh"
OUT=$REPO/bench/results/mutants
ABL=${ABLATED:-$REPO/bench/.ablated}
CSV=$REPO/bench/results/mutants.csv
mkdir -p "$OUT"
[ -f "$ABL/suites/tavern/helpers.py" ] || "$REPO/bench/ablate.sh" "$ABL" >/dev/null
[ -f "$CSV" ] || echo "mutant,suite,run,exit,failed_tests" > "$CSV"
MUTANTS=${*:-$(cd "$REPO/sut/mutants" && ls -d [0-9][0-9]-*)}

# run ROOT SUITE LOG: one pass; echoes "exit,failed;tests"
run() {
  dir=$1/suites/$2
  t0=$(date +%s)
  # Hurl appends to an existing JUnit report instead of replacing it
  rm -f "$dir/.junit.xml"
  mode=par; ROOT=$1 suite_cmd "$2" par >/dev/null || mode=seq
  extra=""
  case $2 in hurl) extra="--report-junit .junit.xml" ;; tavern) extra="--junitxml=/suite/.run/junit.xml" ;; esac
  rc=0; ROOT=$1 sh -c "$(ROOT=$1 suite_cmd "$2" $mode) $extra" > "$3" 2>&1 || rc=$?
  ROOT=$1 assert_no_open_run
  echo "$rc,$(python3 "$REPO/bench/failures.py" "$dir" "$3" "$t0" | paste -sd';')"
  rm -f "$dir/.junit.xml"
}

for m in $MUTANTS; do
  mkdir -p "$OUT/$m"
  for s in $SUITES; do
    "$REPO/sut/mutants/revert.sh" >/dev/null
    assert_no_open_run
    r=$(run "$REPO" "$s" "$OUT/$m/$s-baseline.log")
    echo "$m,$s,baseline,$r" >> "$CSV"
    [ "${r%%,*}" = 0 ] && rm "$OUT/$m/$s-baseline.log"
    "$REPO/sut/mutants/apply.sh" "$m" >/dev/null
    for k in 1 2; do echo "$m,$s,mutant$k,$(run "$REPO" "$s" "$OUT/$m/$s-mutant$k.log")" >> "$CSV"; done
    echo "$m,$s,ablated,$(run "$ABL" "$s" "$OUT/$m/$s-ablated.log")" >> "$CSV"
    echo "$(date +%T) $m $s: $(grep "^$m,$s," "$CSV" | cut -d, -f3,4 | paste -sd' ')"
  done
done
"$REPO/sut/mutants/revert.sh" >/dev/null
