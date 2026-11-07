# 4. Receptionist reads Patients / cannot write them (PUT, POST, JSON Patch).

GET {{url}}/fhir/Patient/{{run_id}}-patient-self
Authorization: Bearer {{rec_token}}
HTTP 200

GET {{url}}/fhir/Patient/{{run_id}}-patient-self?__debug=policy
Authorization: Bearer {{rec_token}}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" == "as-receptionist-read-patients"

GET {{url}}/fhir/Patient?_id={{run_id}}-patient-self,{{run_id}}-patient-other
Authorization: Bearer {{rec_token}}
HTTP 200
[Asserts]
jsonpath "$.entry" count == 2

PUT {{url}}/fhir/Patient/{{run_id}}-patient-self
Authorization: Bearer {{rec_token}}
{"resourceType": "Patient", "id": "{{run_id}}-patient-self", "name": [{"family": "Hacked"}]}
HTTP 403

PUT {{url}}/fhir/Patient/{{run_id}}-patient-self?__debug=policy
Authorization: Bearer {{rec_token}}
{"resourceType": "Patient", "id": "{{run_id}}-patient-self", "name": [{"family": "Hacked"}]}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)]" not exists

POST {{url}}/fhir/Patient
Authorization: Bearer {{rec_token}}
{"resourceType": "Patient", "name": [{"family": "{{run_id}}-rec-created"}]}
HTTP 403

POST {{url}}/fhir/Patient?__debug=policy
Authorization: Bearer {{rec_token}}
{"resourceType": "Patient", "name": [{"family": "{{run_id}}-rec-created"}]}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)]" not exists

PATCH {{url}}/fhir/Patient/{{run_id}}-patient-self
Authorization: Bearer {{rec_token}}
Content-Type: application/json-patch+json
[{"op": "replace", "path": "/name/0/family", "value": "Hacked"}]
HTTP 403

PATCH {{url}}/fhir/Patient/{{run_id}}-patient-self?__debug=policy
Authorization: Bearer {{rec_token}}
Content-Type: application/json-patch+json
[{"op": "replace", "path": "/name/0/family", "value": "Hacked"}]
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)]" not exists

# Nothing was written.
GET {{url}}/fhir/Patient/{{run_id}}-patient-self
[BasicAuth]
root: secret
HTTP 200
[Asserts]
jsonpath "$.name[0].family" == "Bakeoff"
