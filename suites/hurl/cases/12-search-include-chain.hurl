# 12. Search: _include, _revinclude, chaining.

GET {{url}}/fhir/Encounter?_id={{run_id}}-enc-match&_include=Encounter:subject
[BasicAuth]
root: secret
HTTP 200
[Asserts]
jsonpath "$.entry" count == 2
jsonpath "$.entry[?(@.search.mode == 'include')].resource.id" == "{{run_id}}-patient-self"

GET {{url}}/fhir/Patient?_id={{run_id}}-patient-self&_revinclude=Observation:subject
[BasicAuth]
root: secret
HTTP 200
[Asserts]
jsonpath "$.entry" count == 2
jsonpath "$.entry[?(@.resource.resourceType == 'Observation')].resource.id" == "{{run_id}}-obs-match"

GET {{url}}/fhir/Observation?_id={{run_id}}-obs-match,{{run_id}}-obs-mismatch&subject:Patient.given=Other
[BasicAuth]
root: secret
HTTP 200
[Asserts]
jsonpath "$.entry" count == 1
jsonpath "$.entry[0].resource.id" == "{{run_id}}-obs-mismatch"
