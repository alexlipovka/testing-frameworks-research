# Shared by the bench scripts: one pass of each suite, per parallelism mode.
# Sourced with REPO set; ROOT may point at another copy of the repo (ablation).
SUITES="hurl karate pytest playwright tavern"
ROOT=${ROOT:-$REPO}

# suite_cmd SUITE MODE -> shell command for one pass (no runner-level repeat).
# MODE: par = the suite's native parallel mode, seq = one worker. pytest and
# Tavern have no safe parallel mode, so par is not defined for them.
suite_cmd() {
  case "$1:$2" in
    hurl:seq) echo "RUNS=1 $ROOT/suites/hurl/run.sh --jobs 1" ;;
    hurl:par) echo "RUNS=1 $ROOT/suites/hurl/run.sh --jobs $(nproc)" ;;
    karate:seq) echo "THREADS=1 $ROOT/suites/karate/run.sh" ;;
    karate:par) echo "THREADS=4 $ROOT/suites/karate/run.sh" ;;
    pytest:seq) echo "$ROOT/suites/pytest/run.sh" ;;
    playwright:seq) echo "$ROOT/suites/playwright/run.sh -- --workers=1" ;;
    playwright:par) echo "$ROOT/suites/playwright/run.sh -- --workers=4" ;;
    tavern:seq) echo "$ROOT/suites/tavern/run.sh" ;;
    *) return 1 ;;
  esac
}

open_runs() {
  for f in "$ROOT"/sut/fixtures/.vars* "$ROOT"/suites/hurl/.vars "$ROOT"/suites/karate/.vars.json \
           "$ROOT"/suites/playwright/reports/open-run.json "$ROOT"/suites/tavern/.run/state.json; do
    [ -e "$f" ] && echo "$f"
  done
  return 0
}

# Rows any run left behind. pytest keeps its tx stamp only in memory, so a state
# file alone would miss a killed pytest run.
residue() {
  q="SELECT count(*) AS n FROM (SELECT id FROM patient UNION ALL SELECT id FROM \"user\" UNION ALL SELECT id FROM client UNION ALL SELECT id FROM consent UNION ALL SELECT id FROM role UNION ALL SELECT id FROM accesspolicy UNION ALL SELECT id FROM encounter UNION ALL SELECT id FROM observation) t WHERE id LIKE 'bakeoff-%'"
  jq -n --arg q "$q" '{query: $q}' | curl -sfu root:secret -H 'content-type: application/json' \
    "${AIDBOX_URL:-http://localhost:8280}/\$psql" -d @- | jq -r '.result[0].data[0].n'
}

# Stop the whole bench when a run was left open: cleanup is the user's call.
assert_no_open_run() {
  left=$(open_runs)
  n=$(residue)
  [ -z "$left" ] && [ "$n" = 0 ] || { echo "BENCH STOP: run left open: ${left:-none} / bakeoff rows: $n" >&2; exit 3; }
}

# Cold Aidbox. A restart re-applies the upstream allow-all policies, hence the revert.
restart_aidbox() {
  docker compose -f "$REPO/sut/compose.yaml" restart aidbox >/dev/null 2>&1
  until [ "$(docker inspect -f '{{.State.Health.Status}}' bakeoff-sut-aidbox-1)" = healthy ]; do sleep 1; done
  "$REPO/sut/mutants/revert.sh" >/dev/null
}
