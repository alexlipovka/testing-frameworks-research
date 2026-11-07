# 8. One row of table.txt: {{token}} and the four expected statuses.

GET {{url}}/fhir/Patient/{{run_id}}-patient-self
Authorization: Bearer {{token}}
HTTP *
[Asserts]
status == {{read_patient}}

GET {{url}}/fhir/Patient?_id={{run_id}}-patient-self
Authorization: Bearer {{token}}
HTTP *
[Asserts]
status == {{search_patient}}

PUT {{url}}/fhir/Patient/{{run_id}}-patient-self
Authorization: Bearer {{token}}
{"resourceType": "Patient", "id": "{{run_id}}-patient-self", "name": [{"given": ["Self"], "family": "Bakeoff"}]}
HTTP *
[Asserts]
status == {{update_patient}}

GET {{url}}/fhir/Encounter/{{run_id}}-enc-match
Authorization: Bearer {{token}}
HTTP *
[Asserts]
status == {{read_encounter}}
