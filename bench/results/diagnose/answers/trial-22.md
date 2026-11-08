**Root cause:** the AccessPolicy that lets a patient read their own Encounter no longer matches, so the request is cleanly denied. The output does not show this policy's id, because the decisive part of the dump is truncated. It is most likely the patient-role Encounter rule, whatever its id.

**What most likely changed:** that policy's Encounter grant was narrowed or broken in its match conditions. Candidates are the `FhirRead`/Encounter operation or resource-type match, or the check tying `Encounter.subject` to the logged-in patient. The output can't tell these apart. Deletion of the policy is also possible if it covers only Encounter.

**Evidence:**
- Exactly two tests failed, and both are the same request: `pat-self` doing GET `/fhir/Encounter/<enc-match>`.
- In `test_03`, the preceding GET on `/fhir/Patient/<patient-self>` passed, so the patient's login and Patient-read access still work. Its Observation search was never reached, because the loop stopped at Encounter.
- `allowed_by=[]` with `errors=[]` means no policy granted access and none threw. That rules out a policy error such as a broken SQL or engine expression, and points to a condition that evaluates false or a missing grant.
- The only policy id visible is `as-practitioner-sdc-consented-patient`, listed with reason `wrong role`, expected role `practitioner`. That is the expected non-match for a patient caller, so it is not the culprit.
- The other 63 tests passed, including the rest of the role matrix, the search-leak tests and the bypass tests. The change therefore removed access and did not over-grant anywhere the suite checks.

**Decisive lines:**
- `E       AssertionError: expected allow for GET /fhir/Encounter/bakeoff-0a96811e-enc-match: allowed_by=[] errors=[]`
- `FAILED tests/test_08_matrix.py::test_matrix[pat-self-read_encounter] - Assert...`
- `v = Verdict(allowed_by=[], errors=[], dump={'request': {'remote-addr': '172.23.0.7', 'operation': {'id': 'FhirRead', 'reso...ent', 'policy-id': 'as-practitioner-sdc-consented-patient', 'reason': 'wrong role', 'expected-role': 'practitioner'}]})`

**Confidence:** medium that the patient Encounter-read grant stopped matching with no policy error. Low on the exact policy id and the exact field changed, since neither appears in the output.

The count below is the single Read of the log and excludes this handback call.

TOOL_CALLS: 1
