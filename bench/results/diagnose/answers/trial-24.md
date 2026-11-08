**Root cause:** AccessPolicy `as-receptionist-read-patients` was most likely widened to allow the PATCH method on Patient. It should be read-only, but its request-method constraint now probably also accepts `patch`, for example `get` became a one-of list that includes `patch`.

**Why this is the likely change:**
- All 3 failures are the same call: the receptionist client sending PATCH to `/fhir/Patient/{id}`. It fails with both `application/json-patch+json` and `application/merge-patch+json`.
- In each failure the verdict is `allowed_by=['as-receptionist-read-patients']` with `errors=[]`, so this is a clean allow and not a policy error.
- In `test_receptionist_cannot_write_patients`, the PUT and POST `expect_deny` calls on lines before the PATCH passed. The method constraint was therefore not removed outright. PATCH was added specifically.
- The other 62 tests pass, including reads, the role matrix, no-role, SDC and transactions. That points to one narrow change to this policy.

**Limit of the evidence:** the log does not show the policy body, so the exact form of the edit is inferred. `test_json_patch_denied` loops over `(rec, p1)` and failed on `rec` first, so the log says nothing about `p1`. However, `p1` is not implicated by anything else in the output.

**Decisive lines:**
- `E       AssertionError: expected deny for PATCH /fhir/Patient/bakeoff-40f824c9-patient-self: allowed_by=['as-receptionist-read-patients'] errors=[]`
- `>       expect_deny(rec, "PATCH", f"/fhir/Patient/{pid}", headers=JSON_PATCH,` (the line reached only after the PUT and POST denials passed)
- `kw = {'content': '{"name": [{"family": "Hacked"}]}', 'headers': {'Content-Type': 'application/merge-patch+json'}}` (the merge-patch variant is allowed too, so this is method-level and not content-type-specific)

**Confidence:** high on the policy and that it now allows PATCH; medium on the exact form of the edit.

TOOL_CALLS: 1
