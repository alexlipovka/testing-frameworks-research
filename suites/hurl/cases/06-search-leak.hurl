# 6. Searches return nothing outside the caller's scope.

# Patient: own Observations only.
GET {{url}}/fhir/Observation?subject=Patient/{{run_id}}-patient-self&__debug=policy
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" == "as-patient-search-own-observations"

GET {{url}}/fhir/Observation?subject=Patient/{{run_id}}-patient-self
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.entry" count == 1
jsonpath "$.entry[0].resource.id" == "{{run_id}}-obs-match"

GET {{url}}/fhir/Observation?subject=Patient/{{run_id}}-patient-other
Authorization: Bearer {{pat_self_token}}
HTTP 403

GET {{url}}/fhir/Observation?subject=Patient/{{run_id}}-patient-self&subject=Patient/{{run_id}}-patient-other
Authorization: Bearer {{pat_self_token}}
HTTP 403

GET {{url}}/fhir/Observation
Authorization: Bearer {{pat_self_token}}
HTTP 403

GET {{url}}/fhir/Observation?subject=Patient/{{run_id}}-patient-self&_include=Observation:subject
Authorization: Bearer {{pat_self_token}}
HTTP 403

GET {{url}}/fhir/Observation?subject=Patient/{{run_id}}-patient-other&__debug=policy
Authorization: Bearer {{pat_self_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" not exists

# Practitioner: every id must be consented.
GET {{url}}/fhir/Patient?_id={{run_id}}-patient-self
Authorization: Bearer {{p1_token}}
HTTP 200
[Asserts]
jsonpath "$.entry" count == 1
jsonpath "$.entry[0].resource.id" == "{{run_id}}-patient-self"

GET {{url}}/fhir/Patient?_id={{run_id}}-patient-self,{{run_id}}-patient-other&__debug=policy
Authorization: Bearer {{p1_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" not exists

GET {{url}}/fhir/Patient?_id={{run_id}}-patient-self,{{run_id}}-patient-other
Authorization: Bearer {{p1_token}}
HTTP 403

GET {{url}}/fhir/Patient?_id={{run_id}}-patient-self&_revinclude=Observation:subject
Authorization: Bearer {{p1_token}}
HTTP 403

# Receptionist: Patients yes, but includes would drag clinical data along.
GET {{url}}/fhir/Patient?_revinclude=Observation:subject
Authorization: Bearer {{rec_token}}
HTTP 403

GET {{url}}/fhir/Patient?_id={{run_id}}-patient-self&_include=Patient:general-practitioner
Authorization: Bearer {{rec_token}}
HTTP 403
