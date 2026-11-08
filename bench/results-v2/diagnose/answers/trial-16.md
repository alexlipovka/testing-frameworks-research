**Root cause:** the AccessPolicy `as-patient-read-own-encounter` most likely stopped granting. It now evaluates to no-match for the patient reading their own Encounter (`pat-self` GET `/fhir/Encounter/<enc-match>`). The change was probably a narrowed or broken match condition, or the policy being removed or disabled.

**Evidence:**
- All 3 failures are the same request, and all end in a clean deny: `allowed_by=[] errors=[]`.
- With `errors=[]`, the policy did not throw, so a malformed SQL or engine expression is unlikely (no `:auth/policy-error`-style signal).
- In the same `test_baseline_policies_do_not_throw_on_patient_requests` loop, `/fhir/Patient/<self>` passed before the Encounter URL failed. The other 64 tests also passed, including the other matrix cells, so `pat-self` authentication and the patient role in general still work. The Observation URL in that loop was never reached, because the assertion stopped at Encounter.
- Nothing became over-permissive: no deny test failed. That points to a lost grant, not a widened one. The blast radius is exactly the one policy the tests name as the expected allower (`by="as-patient-read-own-encounter"`).

**Limits of the output:** the policy's own evaluation entry is truncated out of the `Verdict` dump. The only visible entry is an unrelated non-match (`as-practitioner-sdc-consented-patient`, `wrong role`), which is expected for a patient. So the output cannot say which of these it was:
- the patient-to-Encounter ownership condition was altered (for example the subject reference or patient-id comparison)
- the role or resource/operation match was changed
- the policy was deleted or its engine or link broken

The ownership or match condition is my best guess, because a patient-scoped Encounter policy is mostly that condition. It is not directly shown.

**Decisive lines:**
- `by = 'as-patient-read-own-encounter', send = True, kw = {}`
- `E       AssertionError: expected allow for GET /fhir/Encounter/bakeoff-8f4e1f50-enc-match: user=bakeoff-8f4e1f50-pat-self allowed_by=[] errors=[]`
- `FAILED tests/test_08_matrix.py::test_matrix[pat-self-read_encounter] - Assert...`

**Confidence:** high on the policy id, low to medium on exactly what changed about it.

The count below covers the single Read and excludes this hand-off call.

TOOL_CALLS: 1
