# 3. A throwing SQL policy is an error, not a plain deny.
# A crashing policy still yields 403 (or 200 via another policy), so only the debug dump tells them apart.

# Allow through the SQL policy: no policy errored.
GET {{url}}/fhir/Encounter/{{run_id}}-enc-match
Authorization: Bearer {{pat_self_token}}
HTTP 200

GET {{url}}/fhir/Encounter/{{run_id}}-enc-match?__debug=policy
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" == "as-patient-read-own-encounter"
jsonpath "$.policies[?(@.error)]" not exists

# Deny through the same SQL policy: it ran (no rows → null), and did not error.
GET {{url}}/fhir/Encounter/{{run_id}}-enc-mismatch
Authorization: Bearer {{pat_self_token}}
HTTP 403

GET {{url}}/fhir/Encounter/{{run_id}}-enc-mismatch?__debug=policy
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)]" not exists
jsonpath "$.policies[?(@.id == 'as-patient-read-own-encounter')].query" exists
jsonpath "$.policies[?(@.error)]" not exists

# A non-Encounter patient request must not crash any policy either.
GET {{url}}/fhir/Condition/{{run_id}}-cond-match?__debug=policy
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@.error)]" not exists
