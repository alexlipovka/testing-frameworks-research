#!/bin/sh
# Smoke test for the SUT: docker compose up -d --wait && ./smoke.sh
set -eu
A=${AIDBOX_URL:-http://localhost:8280}
U=root:secret
get() { curl -sfu $U "$A$1"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

v=$(get /health | jq -r .about.version)
case $v in 2608.*) echo "ok aidbox $v" ;; *) fail "aidbox version $v, want 2608.*" ;; esac

# compose up --wait exits 0 even when build-seeds failed, so check a seeded resource
get /fhir/Questionnaire/glucose >/dev/null || fail "seeds not loaded (no Questionnaire/glucose)"
get /fhir/Patient/patient1 >/dev/null || fail "seeds not loaded (no Patient/patient1)"
get /fhir/Practitioner/receptionist >/dev/null || fail "seeds not loaded (no Practitioner/receptionist)"
echo "ok seeds"

get /App/sdc >/dev/null || fail "sdc app not registered"
echo "ok sdc registered"

# Real $extract through sdc and fhirpath_mapping; it writes an Observation + Provenance, removed below
body=$(jq -n --argjson p "$(get /fhir/Patient/patient1)" --argjson au "$(get /fhir/Practitioner/receptionist)" '{resourceType: "Parameters", parameter: [
  {name: "questionnaire_response", resource: {resourceType: "QuestionnaireResponse", status: "completed",
    questionnaire: "glucose", item: [
      {linkId: "patientId", answer: [{valueString: "patient1"}]},
      {linkId: "glucose-level", answer: [{valueDecimal: 5.5}]},
      {linkId: "dateTime", answer: [{valueDateTime: "2026-01-01T00:00:00Z"}]}]}},
  {name: "Patient", resource: $p},
  {name: "Author", resource: $au},
  {name: "ProvenanceBundle", resource: {resourceType: "Bundle", type: "collection", entry: []}}]}')
out=$(curl -su $U -H 'content-type: application/json' -X POST "$A/fhir/Questionnaire/glucose/\$extract" -d "$body")
refs=$(printf '%s\n' "$out" | jq -r '.[].entry[].resource | "\(.resourceType)/\(.id)"' 2>/dev/null) \
  || fail "\$extract: $out"
for r in $refs; do curl -sfu $U -X DELETE "$A/fhir/$r" >/dev/null || fail "cleanup $r"; done
echo "$refs" | grep -q '^Observation/' || fail "\$extract created no Observation: $out"
echo "ok sdc \$extract"
