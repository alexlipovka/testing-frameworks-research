#!/bin/sh
# mutants.sh [MUTANT...]: every mutant (default all) x every suite in native mode:
# baseline run, mutant run twice, decision-ablated copy once -> $RESULTS/mutants.csv,
# logs in $RESULTS/mutants/<mutant>/. MUTANTS_DIR picks another set of mutants.
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
. "$REPO/bench/lib.sh"
OUT=$RESULTS/mutants
ABL=${ABLATED:-$REPO/bench/.ablated-v2}
CSV=$RESULTS/mutants.csv
mkdir -p "$OUT"
[ -f "$ABL/suites/tavern/helpers.py" ] || "$REPO/bench/ablate.sh" "$ABL" >/dev/null
[ -f "$CSV" ] || echo "mutant,suite,run,exit,failed_tests" > "$CSV"
MUTANTS=${*:-$(cd "${MUTANTS_DIR:-$REPO/sut/mutants}" && ls -d */ | tr -d /)}

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
    # Each mutant starts from green; every red attempt stays in the CSV as a flake
    for b in baseline baseline-retry1 baseline-retry2; do
      r=$(run "$REPO" "$s" "$OUT/$m/$s-$b.log")
      echo "$m,$s,$b,$r" >> "$CSV"
      if [ "${r%%,*}" = 0 ]; then rm "$OUT/$m/$s-$b.log"; break; fi
    done
    "$REPO/sut/mutants/apply.sh" "$m" >/dev/null
    for k in 1 2; do echo "$m,$s,mutant$k,$(run "$REPO" "$s" "$OUT/$m/$s-mutant$k.log")" >> "$CSV"; done
    echo "$m,$s,ablated,$(run "$ABL" "$s" "$OUT/$m/$s-ablated.log")" >> "$CSV"
    echo "$(date +%T) $m $s: $(grep "^$m,$s," "$CSV" | cut -d, -f3,4 | paste -sd' ')"
  done
done
"$REPO/sut/mutants/revert.sh" >/dev/null
