# 1. Patient reads own record (matcho) / is denied another patient's.

GET {{url}}/fhir/Patient/{{run_id}}-patient-self?__debug=policy
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" == "patient-role-policy"
jsonpath "$.policies[?(search(@.error, '.'))].error" not exists

GET {{url}}/fhir/Patient/{{run_id}}-patient-self
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{run_id}}-patient-self"

GET {{url}}/fhir/Patient/{{run_id}}-patient-other?__debug=policy
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" not exists
jsonpath "$.policies[?(search(@.error, '.'))].error" not exists

GET {{url}}/fhir/Patient/{{run_id}}-patient-other
Authorization: Bearer {{pat_self_token}}
HTTP 403

# Own Encounter is allowed by the SQL policy.
GET {{url}}/fhir/Encounter/{{run_id}}-enc-match?__debug=policy
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" == "as-patient-read-own-encounter"
jsonpath "$.policies[?(search(@.error, '.'))].error" not exists

GET {{url}}/fhir/Encounter/{{run_id}}-enc-match
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{run_id}}-enc-match"

# Another patient's Encounter is denied.
GET {{url}}/fhir/Encounter/{{run_id}}-enc-mismatch?__debug=policy
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" not exists
jsonpath "$.policies[?(search(@.error, '.'))].error" not exists

GET {{url}}/fhir/Encounter/{{run_id}}-enc-mismatch
Authorization: Bearer {{pat_self_token}}
HTTP 403

# The own-Encounter id under another resource type is denied.
GET {{url}}/fhir/Observation/{{run_id}}-enc-match?__debug=policy
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" not exists
jsonpath "$.policies[?(search(@.error, '.'))].error" not exists

GET {{url}}/fhir/Observation/{{run_id}}-enc-match
Authorization: Bearer {{pat_self_token}}
HTTP 403
