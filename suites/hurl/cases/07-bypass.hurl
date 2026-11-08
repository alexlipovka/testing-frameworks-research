# 7. Bypass attempts: transaction Bundle, JSON Patch, merge-patch.

# Allow baseline: the same reads succeed directly.
GET {{url}}/fhir/Patient/{{run_id}}-patient-self
Authorization: Bearer {{pat_self_token}}
HTTP 200

# A read of someone else's Patient smuggled in a transaction.
POST {{url}}/fhir?__debug=policy
Authorization: Bearer {{pat_self_token}}
{"resourceType": "Bundle", "type": "transaction", "entry": [
  {"request": {"method": "GET", "url": "Patient/{{run_id}}-patient-other"}}]}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" not exists

POST {{url}}/fhir
Authorization: Bearer {{pat_self_token}}
{"resourceType": "Bundle", "type": "transaction", "entry": [
  {"request": {"method": "GET", "url": "Patient/{{run_id}}-patient-other"}}]}
HTTP 403

# A write the receptionist may not do directly, wrapped in a transaction.
POST {{url}}/fhir
Authorization: Bearer {{rec_token}}
{"resourceType": "Bundle", "type": "transaction", "entry": [
  {"request": {"method": "PUT", "url": "Patient/{{run_id}}-patient-self"},
   "resource": {"resourceType": "Patient", "id": "{{run_id}}-patient-self", "name": [{"family": "Hacked"}]}}]}
HTTP 403

PATCH {{url}}/fhir/Patient/{{run_id}}-patient-self
Authorization: Bearer {{rec_token}}
Content-Type: application/json-patch+json
[{"op": "replace", "path": "/name/0/family", "value": "Hacked"}]
HTTP 403

PATCH {{url}}/fhir/Patient/{{run_id}}-patient-self?__debug=policy
Authorization: Bearer {{rec_token}}
Content-Type: application/merge-patch+json
{"name": [{"family": "Hacked"}]}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" not exists

PATCH {{url}}/fhir/Patient/{{run_id}}-patient-self
Authorization: Bearer {{rec_token}}
Content-Type: application/merge-patch+json
{"name": [{"family": "Hacked"}]}
HTTP 403

# The allowed side of PATCH: receptionist may patch Appointments.
PATCH {{url}}/fhir/Appointment/{{run_id}}-appt-match
Authorization: Bearer {{rec_token}}
Content-Type: application/json-patch+json
[{"op": "add", "path": "/comment", "value": "patched by rec"}]
HTTP 200

GET {{url}}/fhir/Patient/{{run_id}}-patient-self
[BasicAuth]
root: secret
HTTP 200
[Asserts]
jsonpath "$.name[0].family" == "Bakeoff"
