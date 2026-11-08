#!/bin/sh
# Install the bake-off AccessPolicies, optionally with one mutant swapped in. curl only.
#
#   apply.sh NAME   baseline (../policies/*.yaml), then mutants/NAME/*.yaml on top
#   apply.sh        baseline only (what revert.sh runs)
#
# MUTANTS_DIR picks another set of mutants (default: this directory).
#
# Between runs only: a fixture teardown deletes every row written after its stamp,
# policies included.
set -eu

DIR=$(cd "$(dirname "$0")" && pwd)
SUT=$(dirname "$DIR")
MUTANTS=${MUTANTS_DIR:-$DIR}
A=${AIDBOX_URL:-http://localhost:8280}
ADMIN=${ADMIN:-root:secret}
fail() { echo "FAIL: $*" >&2; exit 1; }
yaml_id() { sed -n 's/^id: *//p' "$1" | head -n1; }

for v in "$SUT"/fixtures/.vars*; do
  [ ! -f "$v" ] || fail "a run is open ($v): fixtures/run.sh teardown first"
done
name=${1:-}
[ -z "$name" ] || [ -d "$MUTANTS/$name" ] || fail "no mutant $name (see $MUTANTS)"

put() {
  curl -sfu "$ADMIN" -o /dev/null -X PUT -H 'content-type: text/yaml' -H 'accept: application/json' \
    "$A/AccessPolicy/$(yaml_id "$1")" --data-binary "@$1" || fail "PUT $1"
}

# A mutant may add a policy the baseline lacks; the previous mutant's must not linger
for f in "$MUTANTS"/*/*.yaml; do
  id=$(yaml_id "$f")
  [ -f "$SUT/policies/$id.yaml" ] && continue
  curl -sfu "$ADMIN" -o /dev/null -X DELETE "$A/AccessPolicy/$id" || fail "DELETE $id"
done
for f in "$SUT"/policies/*.yaml; do put "$f"; done
for f in ${name:+"$MUTANTS/$name"/*.yaml}; do put "$f"; done
echo "policies: baseline${name:+ + $name}"
