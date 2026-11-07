# 11. Invalid resource → 422 OperationOutcome.

POST {{url}}/fhir/Patient
[BasicAuth]
root: secret
{"resourceType": "Patient", "name": [{"family": "{{run_id}}-invalid"}], "active": "yes"}
HTTP 422
[Asserts]
jsonpath "$.resourceType" == "OperationOutcome"
jsonpath "$.issue[0].severity" matches "^(error|fatal)$"

POST {{url}}/fhir/Patient
[BasicAuth]
root: secret
{"resourceType": "Patient", "name": [{"family": "{{run_id}}-invalid"}], "unknownField": 1}
HTTP 422
[Asserts]
jsonpath "$.resourceType" == "OperationOutcome"
