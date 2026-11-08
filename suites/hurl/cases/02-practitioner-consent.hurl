# 2. Practitioner reads a Patient through an active Consent (SQL) / a revoked Consent denies.

GET {{url}}/fhir/Patient/{{run_id}}-patient-self?__debug=policy
Authorization: Bearer {{p1_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" == "practitioner-policy"

GET {{url}}/fhir/Patient/{{run_id}}-patient-self
Authorization: Bearer {{p1_token}}
HTTP 200

# p2's own Consent: proves the policy uses the logged-in practitioner, not a fixed id.
GET {{url}}/fhir/Patient/{{run_id}}-patient-other
Authorization: Bearer {{p2_token}}
HTTP 200

# p1's Consent on patient-other is inactive.
GET {{url}}/fhir/Patient/{{run_id}}-patient-other?__debug=policy
Authorization: Bearer {{p1_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" not exists
jsonpath "$.policies[?(search(@.error, '.'))].error" not exists

GET {{url}}/fhir/Patient/{{run_id}}-patient-other
Authorization: Bearer {{p1_token}}
HTTP 403
