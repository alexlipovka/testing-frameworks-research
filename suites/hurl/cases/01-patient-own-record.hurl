# 1. Patient reads own record (matcho) / is denied another patient's.

GET {{url}}/fhir/Patient/{{run_id}}-patient-self
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{run_id}}-patient-self"

GET {{url}}/fhir/Patient/{{run_id}}-patient-self?__debug=policy
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" == "patient-role-policy"
jsonpath "$.policies[?(@.error)]" not exists

GET {{url}}/fhir/Patient/{{run_id}}-patient-other
Authorization: Bearer {{pat_self_token}}
HTTP 403

GET {{url}}/fhir/Patient/{{run_id}}-patient-other?__debug=policy
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)]" not exists
jsonpath "$.policies[?(@.error)]" not exists
