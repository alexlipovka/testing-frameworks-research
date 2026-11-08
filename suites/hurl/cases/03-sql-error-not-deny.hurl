# 3. A throwing SQL policy is an error, not a plain deny.
# A crashing policy still yields 403 (or 200 via another policy), so only the debug dump tells them apart.

# Allow through the SQL policy: no policy errored.
GET {{url}}/fhir/Encounter/{{run_id}}-enc-match?__debug=policy
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" == "as-patient-read-own-encounter"
jsonpath "$.policies[?(search(@.error, '.'))].error" not exists

GET {{url}}/fhir/Encounter/{{run_id}}-enc-match
Authorization: Bearer {{pat_self_token}}
HTTP 200

# Deny through the same SQL policy: it ran (no rows → null), and did not error.
GET {{url}}/fhir/Encounter/{{run_id}}-enc-mismatch?__debug=policy
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" not exists
jsonpath "$.policies[?(@.id == 'as-patient-read-own-encounter')].query" exists
jsonpath "$.policies[?(search(@.error, '.'))].error" not exists

GET {{url}}/fhir/Encounter/{{run_id}}-enc-mismatch
Authorization: Bearer {{pat_self_token}}
HTTP 403

# A non-Encounter patient request must not crash any policy either.
GET {{url}}/fhir/Condition/{{run_id}}-cond-match?__debug=policy
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(search(@.error, '.'))].error" not exists

# A policy that really throws: `parameter` as an object breaks the SDC policy's jsonb_array_elements.
# The client sees a plain 403; only the dump shows the error.
POST {{url}}/fhir/Questionnaire/glucose/$populate?__debug=policy
Authorization: Bearer {{p1_token}}
{"resourceType": "Parameters", "parameter": {"name": "subject", "valueReference": {"reference": "Patient/{{run_id}}-patient-self"}}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" not exists
jsonpath "$.policies[?(search(@.error, '.'))].id" == "as-practitioner-sdc-consented-patient"
jsonpath "$.policies[?(search(@.error, '.'))].error" contains "cannot extract elements"

POST {{url}}/fhir/Questionnaire/glucose/$populate
Authorization: Bearer {{p1_token}}
{"resourceType": "Parameters", "parameter": {"name": "subject", "valueReference": {"reference": "Patient/{{run_id}}-patient-self"}}}
HTTP 403
