#!/bin/sh
# Reference implementation of the shared fixture contract (README.md). curl + jq.
#
#   run.sh lint        offline: fixtures.json has the shape the contract promises
#   run.sh setup       open a run, write its vars to $FIXTURES_VARS
#   run.sh teardown    roll the database back to the run's tx stamp
#   run.sh check       live: setup, probe each identity, teardown, no residue; twice
set -eu

DIR=$(cd "$(dirname "$0")" && pwd)
DATA="$DIR/fixtures.json"
VARS=${FIXTURES_VARS:-$DIR/.vars}
A=${AIDBOX_URL:-http://localhost:8280}
ADMIN=${ADMIN:-root:secret}
fail() { echo "FAIL: $*" >&2; exit 1; }
var() { sed -n "s/^$1=//p" "$VARS"; }

aidbox_sql() {
  out=$(jq -n --arg q "$1" '{query: $q}' | curl -sfu "$ADMIN" -H 'content-type: application/json' "$A/\$psql" -d @-) \
    || fail "\$psql: $1"
  printf '%s' "$out" | jq -e '.status == "success"' >/dev/null || fail "\$psql: $out"
  printf '%s' "$out"
}

setup() {
  [ ! -f "$VARS" ] || fail "a run is open ($VARS): run.sh teardown first"
  run_id="bakeoff-$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
  data=$(jq --arg r "$run_id" 'walk(if type == "string" then gsub("\\{\\{run_id\\}\\}"; $r) else . end)' "$DATA")
  aidbox_sql "$(printf '%s' "$data" | jq -r .sql.install)" >/dev/null
  tx_id=$(aidbox_sql "$(printf '%s' "$data" | jq -r .sql.stamp)" | jq -r '.result[0].data[0].last_value')
  # Written before the first fixture, so a failed setup can still be torn down
  printf 'run_id=%s\ntx_id=%s\n' "$run_id" "$tx_id" > "$VARS"
  printf '%s' "$data" | jq -c '.setup[]' | while read -r req; do
    path=$(printf '%s' "$req" | jq -r .path)
    printf '%s' "$req" | jq -c .body | curl -sfu "$ADMIN" -o /dev/null -X "$(printf '%s' "$req" | jq -r .method)" \
      -H 'content-type: application/json' "$A$path" -d @- || fail "setup $path"
  done
  printf '%s' "$data" | jq -c '.secrets as $s | .identities[] | {token_var, body: {grant_type: "password",
      client_id: $s.client_id, client_secret: $s.client_secret, username: .user, password: $s.user_password}}' \
    | while read -r id; do
      token=$(printf '%s' "$id" | jq -c .body | curl -sf -H 'content-type: application/json' "$A/auth/token" -d @- \
        | jq -er .access_token) || fail "token $(printf '%s' "$id" | jq -r .token_var)"
      echo "$(printf '%s' "$id" | jq -r .token_var)=$token" >> "$VARS"
    done
  echo "run $run_id open (vars in $VARS)"
}

teardown() {
  [ -f "$VARS" ] || return 0
  aidbox_sql "$(jq -r .sql.rollback "$DATA" | sed "s/{{tx_id}}/$(var tx_id)/")" >/dev/null
  rm -f "$VARS"
}

lint() {
  jq -e . "$DATA" >/dev/null || fail "fixtures.json is not JSON"
  got=$(jq -r '[.identities[].name] | join(" ")' "$DATA")
  [ "$got" = "pat-self p1 p2 rec norole" ] || fail "identities: $got"
  # A misspelt token like {run_id} survives substitution as a literal id, so reject it
  bad=$(jq -r '.. | strings | select(test("run_id") and (test("\\{\\{run_id\\}\\}") | not))' "$DATA")
  [ -z "$bad" ] || fail "malformed run_id token: $bad"
  bad=$(jq -r '.setup[] | select(.body.id | startswith("{{run_id}}-") | not) | .path' "$DATA")
  [ -z "$bad" ] || fail "id without run_id prefix: $bad"
  bad=$(jq -r '.setup[] | select("/\(.body.resourceType)/\(.body.id)" as $t | .path | endswith($t) | not) | .path' "$DATA")
  [ -z "$bad" ] || fail "path does not match body: $bad"
  for f in patient-self patient-other patient-unlinked enc-match enc-mismatch obs-match obs-mismatch; do
    jq -e --arg id "{{run_id}}-$f" 'any(.setup[]; .body.id == $id)' "$DATA" >/dev/null || fail "missing fixture $f"
  done
  echo "ok lint"
}

status() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

check_once() {
  trap teardown EXIT
  setup
  run_id=$(var run_id)
  for t in $(jq -r '.identities[].token_var' "$DATA"); do
    [ -n "$(var "$t")" ] || fail "no $t"
  done
  s=$(status -H "Authorization: Bearer $(var pat_self_token)" "$A/fhir/Patient/$run_id-patient-self")
  [ "$s" = 200 ] || fail "pat-self reads own Patient: $s"
  s=$(status -H "Authorization: Bearer $(var norole_token)" "$A/fhir/Patient/$run_id-patient-self")
  [ "$s" = 403 ] || fail "norole reads a Patient: $s"
  teardown
  trap - EXIT
  for p in "/Client/$run_id-client" "/User/$run_id-pat-self" "/fhir/Patient/$run_id-patient-self" "/fhir/Consent/$run_id-consent-p1-other-revoked"; do
    s=$(status -u "$ADMIN" "$A$p")
    [ "$s" = 404 ] || fail "residue after teardown: $p ($s)"
  done
  echo "ok run $run_id: setup, 5 tokens, teardown, no residue"
}

cmd=${1:-}
case "$cmd" in
  lint) lint ;;
  setup) setup ;;
  teardown) teardown ;;
  check) lint; check_once; check_once ;;
  *) sed -n '2,7p' "$0" >&2; exit 2 ;;
esac
