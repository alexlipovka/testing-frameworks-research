# 14. run_id isolation: this run sees exactly its own fixtures, nothing left by earlier runs.
# The fixture Patients share family "Bakeoff"; :exact because a plain string search is a prefix match
# and the "{{run_id}}-..." families the cases create start with "bakeoff-".

GET {{url}}/fhir/Patient?family:exact=Bakeoff&_count=100
[BasicAuth]
root: secret
HTTP 200
[Asserts]
jsonpath "$.entry" count == 3
jsonpath "$.entry[*].resource.id" contains "{{run_id}}-patient-self"
jsonpath "$.entry[*].resource.id" contains "{{run_id}}-patient-other"
jsonpath "$.entry[*].resource.id" contains "{{run_id}}-patient-unlinked"

# Tokens are bound to this run's users.
GET {{url}}/auth/userinfo
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{run_id}}-pat-self"
