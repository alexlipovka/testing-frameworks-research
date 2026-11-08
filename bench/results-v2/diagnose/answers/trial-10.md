**Root cause:** AccessPolicy `practitioner-policy` was most likely loosened in its consent check. It now lets a practitioner read a Patient whose consent has been revoked. The most specific candidate is that the condition requiring the Consent to be active (e.g. `status = active`, or a not-revoked/period check) was removed or weakened.

**Evidence:**
- Exactly 1 of 67 tests failed: `test_revoked_consent_denies`. User `p1` requested `GET /fhir/Patient/<patient-other>`, and the test expected a deny.
- The verdict shows `practitioner-policy` as the policy that allowed the request, with no policy errors. So this is a real over-grant, not an evaluation failure or an engine error.
- The 66 other tests still pass, which suggests the policy was not dropped, its role match still works, and access was not broadly opened. The change looks limited to how revoked consent is handled.

**Limits of the output:** The log does not show the policy body, and the verdict dump is truncated. "Status/revocation check removed" is therefore inferred from the test name and the single failure. I can't rule out a nearby change that has the same effect, such as a broadened consent-matching condition that the other deny tests don't exercise.

**Decisive lines:**
- `E       AssertionError: expected deny for GET /fhir/Patient/bakeoff-741c6058-patient-other: user=bakeoff-741c6058-p1 allowed_by=['practitioner-policy'] errors=[]`
- `FAILED tests/test_02_practitioner_consent.py::test_revoked_consent_denies - A...`
- `========================= 1 failed, 66 passed in 1.10s =========================`

**Confidence:** high on the policy id (`practitioner-policy`), medium on what exactly changed.

TOOL_CALLS: 1
