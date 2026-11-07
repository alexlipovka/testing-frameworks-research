# 13. Transaction Bundle: urn:uuid references resolve; a failing entry rolls back the whole Bundle.

POST {{url}}/fhir
[BasicAuth]
root: secret
{"resourceType": "Bundle", "type": "transaction", "entry": [
  {"fullUrl": "urn:uuid:6f2b8c1e-0000-4000-8000-000000000001",
   "request": {"method": "POST", "url": "Patient"},
   "resource": {"resourceType": "Patient", "name": [{"family": "{{run_id}}-tx"}]}},
  {"request": {"method": "POST", "url": "Observation"},
   "resource": {"resourceType": "Observation", "status": "final", "code": {"text": "tx"},
                "subject": {"reference": "urn:uuid:6f2b8c1e-0000-4000-8000-000000000001"}}}]}
HTTP 200
[Captures]
patient: jsonpath "$.entry[0].response.location" regex "Patient/([^/]+)"
obs: jsonpath "$.entry[1].response.location" regex "Observation/([^/]+)"
[Asserts]
jsonpath "$.type" == "transaction-response"
jsonpath "$.entry[0].response.status" startsWith "201"
jsonpath "$.entry[1].response.status" startsWith "201"

GET {{url}}/fhir/Observation/{{obs}}
[BasicAuth]
root: secret
HTTP 200
[Asserts]
jsonpath "$.subject.reference" == "Patient/{{patient}}"

# Second entry is invalid: the first must not survive.
POST {{url}}/fhir
[BasicAuth]
root: secret
{"resourceType": "Bundle", "type": "transaction", "entry": [
  {"request": {"method": "PUT", "url": "Patient/{{run_id}}-tx-rollback"},
   "resource": {"resourceType": "Patient", "id": "{{run_id}}-tx-rollback"}},
  {"request": {"method": "POST", "url": "Patient"},
   "resource": {"resourceType": "Patient", "active": "yes"}}]}
HTTP *
[Asserts]
status >= 400

GET {{url}}/fhir/Patient/{{run_id}}-tx-rollback
[BasicAuth]
root: secret
HTTP 404
