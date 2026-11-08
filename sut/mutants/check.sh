#!/bin/sh
# Checks the mutant set itself, not a suite. curl + jq + yq.
#
#   check.sh lint    offline: every mutant is well formed and differs from the baseline
#   check.sh live    every mutant's probe gets a different verdict than under the baseline
#
# MUTANTS_DIR picks another set of mutants (default: this directory).
#
# A verdict is what ?__debug=policy says: allow or deny, plus "+error" if any policy crashed.
set -eu

DIR=$(cd "$(dirname "$0")" && pwd)
SUT=$(dirname "$DIR")
MUTANTS=${MUTANTS_DIR:-$DIR}
RUN="$SUT/fixtures/run.sh"
A=${AIDBOX_URL:-http://localhost:8280}
fail() { echo "FAIL: $*" >&2; exit 1; }
yaml_id() { sed -n 's/^id: *//p' "$1" | head -n1; }
mutants() { for m in "$MUTANTS"/*/; do basename "$m"; done; }

lint() {
  for f in "$SUT"/policies/*.yaml; do
    yq -e '.resourceType == "AccessPolicy"' "$f" >/dev/null || fail "not an AccessPolicy: $f"
    [ "$(yaml_id "$f").yaml" = "$(basename "$f")" ] || fail "id does not match file name: $f"
  done
  identities=$(jq -c '[.identities[].name]' "$SUT/fixtures/fixtures.json")
  for m in $(mutants); do
    d="$MUTANTS/$m"
    ls "$d"/*.yaml >/dev/null 2>&1 || fail "$m: no policy file"
    for f in "$d"/*.yaml; do
      yq -e '.resourceType == "AccessPolicy"' "$f" >/dev/null || fail "$m: not an AccessPolicy: $f"
      [ "$(yaml_id "$f").yaml" = "$(basename "$f")" ] || fail "$m: id does not match file name: $f"
      ! cmp -s "$f" "$SUT/policies/$(basename "$f")" || fail "$m: $(basename "$f") is the baseline unchanged"
    done
    jq -e --argjson ids "$identities" '(.as | IN($ids[])) and (.method | type == "string") and (.path | startswith("/"))' \
      "$d/probe.json" >/dev/null 2>&1 || fail "$m: probe.json needs as (an identity), method, path"
  done
  echo "ok lint: $(mutants | wc -l) mutants"
}

# The probe's verdict in the open run
verdict() {
  run_id=$(sed -n 's/^run_id=//p' "$SUT/fixtures/.vars")
  probe=$(jq --arg r "$run_id" 'walk(if type == "string" then gsub("\\{\\{run_id\\}\\}"; $r) else . end)' "$1")
  var=$(jq -r --arg n "$(printf '%s' "$probe" | jq -r .as)" '.identities[] | select(.name == $n) | .token_var' \
    "$SUT/fixtures/fixtures.json")
  token=$(sed -n "s/^$var=//p" "$SUT/fixtures/.vars")
  path=$(printf '%s' "$probe" | jq -r .path)
  case $path in *\?*) url="$A$path&__debug=policy" ;; *) url="$A$path?__debug=policy" ;; esac
  printf '%s' "$probe" | jq -c '.body // empty' | curl -s -X "$(printf '%s' "$probe" | jq -r .method)" \
    -H "Authorization: Bearer $token" \
    -H "content-type: $(printf '%s' "$probe" | jq -r '.content_type // "application/fhir+json"')" \
    "$url" --data-binary @- \
    | jq -er '(if any(.policies[]; .["eval-result"] == true) then "allow" else "deny" end)
        + (if any(.policies[]; .error != null) then "+error" else "" end)' \
    || fail "no debug dump for $1"
}

live() {
  lint
  trap '"$RUN" teardown >/dev/null; "$DIR/revert.sh" >/dev/null' EXIT
  "$DIR/revert.sh" >/dev/null
  "$RUN" setup >/dev/null
  base=
  for m in $(mutants); do
    base_verdict=$(verdict "$MUTANTS/$m/probe.json")
    base="$base$m $base_verdict
"
  done
  "$RUN" teardown >/dev/null
  equivalent=0
  for m in $(mutants); do
    base_verdict=$(printf '%s' "$base" | sed -n "s/^$m //p")
    case $base_verdict in *+error) fail "baseline crashes a policy on $m's probe" ;; esac
    "$DIR/apply.sh" "$m" >/dev/null
    "$RUN" setup >/dev/null
    mutant_verdict=$(verdict "$MUTANTS/$m/probe.json")
    "$RUN" teardown >/dev/null
    if [ "$mutant_verdict" = "$base_verdict" ]; then
      echo "EQUIVALENT  $m  ($base_verdict either way)"
      equivalent=$((equivalent + 1))
    else
      echo "ok  $m  $base_verdict -> $mutant_verdict"
    fi
  done
  [ "$equivalent" -eq 0 ] || fail "$equivalent mutant(s) change nothing their probe can see"
}

case ${1:-} in
  lint) lint ;;
  live) live ;;
  *) sed -n '2,9p' "$0" >&2; exit 2 ;;
esac
