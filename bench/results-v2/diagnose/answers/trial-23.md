**Root cause:** AccessPolicy `as-receptionist-read-patients` most likely had its request-method matcher widened to admit PATCH, for example `patch` added to a method list that was read-only (GET, maybe search) at baseline. The policy now grants the receptionist PATCH on `/fhir/Patient/{id}`.

**Evidence:**
- All 3 failures are the same request shape: user `bakeoff-ca56083b-rec`, PATCH on `/fhir/Patient/bakeoff-ca56083b-patient-self`. JSON Patch and merge-patch both fail, so the content type doesn't matter.
- The grant comes from one policy, the receptionist's read policy, and `errors=[]` rules out a policy evaluation error.
- In `test_receptionist_cannot_write_patients`, the PUT and POST `expect_deny` calls on lines 22-23 passed, and only the PATCH call failed. The same instance URL is still denied for PUT, so this is specific to the method and not a broadened URI, role or engine condition.
- The other 64 tests passed, so receptionist reads and the other roles' boundaries appear intact.

**Limits of the output:** It can't show the exact matcher edit. A loosened form that excludes only some methods (a `$not` style) can't be fully ruled out, though PUT and POST still being denied makes "patch added" the simplest reading. `test_json_patch_denied` stopped at `rec`, so the `p1` client was never checked in that test.

**Decisive lines:**
- `E       AssertionError: expected deny for PATCH /fhir/Patient/bakeoff-ca56083b-patient-self: user=bakeoff-ca56083b-rec allowed_by=['as-receptionist-read-patients'] errors=[]`
- `>       expect_deny(rec, "PATCH", f"/fhir/Patient/{pid}", headers=JSON_PATCH,` (the failing line, reached only after the PUT and POST denies on the two lines before it passed)
- `FAILED tests/test_07_bypass.py::test_merge_patch_denied - AssertionError: exp...`

**Confidence:** high on the policy and on PATCH being newly allowed; medium on the exact form of the matcher change.

TOOL_CALLS: 1
