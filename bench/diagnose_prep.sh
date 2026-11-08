#!/bin/sh
# diagnose_prep.sh TRIAL_DIR: time-to-diagnose inputs (mutants 05 09 10 11 13 x 5 suites).
# Each suite's first mutant-run log goes to $RESULTS/diagnose/<mutant>/<suite>.log and,
# under a shuffled neutral name, to TRIAL_DIR: all a diagnosing agent sees.
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
. "$REPO/bench/lib.sh"
OUT=$RESULTS/diagnose
TRIALS=$1
mkdir -p "$OUT" "$TRIALS"
echo "trial,mutant,suite,killed" > "$OUT/trials.csv"
i=0
for m in 05-revoked-consent-counts 09-silent-sql-deny 10-single-braces-masked 11-scope-drift 13-patch-bypass; do
  mkdir -p "$OUT/$m"
  for s in $SUITES; do
    killed=$(awk -F, -v m="$m" -v s="$s" '$1 == m && $2 == s {print $3}' "$RESULTS/mutant-matrix.csv")
    cp "$RESULTS/mutants/$m/$s-mutant1.log" "$OUT/$m/$s.log"
    echo "$m,$s,$killed"
  done
done | shuf | while IFS=, read -r m s killed; do
  i=$((i + 1)); t=$(printf 'trial-%02d' "$i")
  sed 's/\x1b\[[0-9;]*m//g' "$OUT/$m/$s.log" > "$TRIALS/$t.log"
  echo "$t,$m,$s,$killed" >> "$OUT/trials.csv"
done
