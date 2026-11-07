# 10. CRUD + JSON Patch as admin.

POST {{url}}/fhir/Patient
[BasicAuth]
root: secret
{"resourceType": "Patient", "name": [{"family": "{{run_id}}-crud"}], "active": true}
HTTP 201
[Captures]
id: jsonpath "$.id"
[Asserts]
jsonpath "$.meta.versionId" exists

GET {{url}}/fhir/Patient/{{id}}
[BasicAuth]
root: secret
HTTP 200
[Asserts]
jsonpath "$.name[0].family" == "{{run_id}}-crud"

PUT {{url}}/fhir/Patient/{{id}}
[BasicAuth]
root: secret
{"resourceType": "Patient", "id": "{{id}}", "name": [{"family": "{{run_id}}-crud"}], "active": false}
HTTP 200
[Asserts]
jsonpath "$.active" == false

PATCH {{url}}/fhir/Patient/{{id}}
Content-Type: application/json-patch+json
[BasicAuth]
root: secret
[{"op": "add", "path": "/gender", "value": "female"}]
HTTP 200
[Asserts]
jsonpath "$.gender" == "female"
jsonpath "$.active" == false

DELETE {{url}}/fhir/Patient/{{id}}
[BasicAuth]
root: secret
HTTP 200

GET {{url}}/fhir/Patient/{{id}}
[BasicAuth]
root: secret
HTTP 410
