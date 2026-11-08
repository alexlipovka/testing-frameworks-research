# 5. A user with no Role is denied everywhere.
# Allow side: the first read, by an identity whose role covers it.

GET {{url}}/fhir/Patient/{{run_id}}-patient-self
Authorization: Bearer {{pat_self_token}}
HTTP 200

GET {{url}}/fhir/Patient/{{run_id}}-patient-self?__debug=policy
Authorization: Bearer {{norole_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" not exists
jsonpath "$.policies[?(search(@.error, '.'))].error" not exists

GET {{url}}/fhir/Patient/{{run_id}}-patient-self
Authorization: Bearer {{norole_token}}
HTTP 403

GET {{url}}/fhir/Patient?__debug=policy
Authorization: Bearer {{norole_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" not exists

GET {{url}}/fhir/Patient
Authorization: Bearer {{norole_token}}
HTTP 403

GET {{url}}/fhir/Encounter/{{run_id}}-enc-match
Authorization: Bearer {{norole_token}}
HTTP 403

GET {{url}}/fhir/Observation?subject=Patient/{{run_id}}-patient-self
Authorization: Bearer {{norole_token}}
HTTP 403

GET {{url}}/fhir/Appointment/{{run_id}}-appt-match
Authorization: Bearer {{norole_token}}
HTTP 403

POST {{url}}/fhir/Patient
Authorization: Bearer {{norole_token}}
{"resourceType": "Patient", "name": [{"family": "{{run_id}}-norole-created"}]}
HTTP 403

POST {{url}}/fhir/Questionnaire/glucose/$populate
Authorization: Bearer {{norole_token}}
{"resourceType": "Parameters", "parameter": [{"name": "subject", "valueReference": {"reference": "Patient/{{run_id}}-patient-self"}}]}
HTTP 403
