**Root cause:** the AccessPolicy `practitioner-policy` was most likely loosened in its consent check. It probably no longer takes the Consent's state into account, for example the `status = active` condition was removed or widened, so a revoked Consent still grants access. The practitioner can now read a Patient whose consent was revoked.

**Reasoning:**
- 1 of 65 tests failed: `test_revoked_consent_denies`. The practitioner client `p1` was expected to be denied on `GET /fhir/Patient/<run>-patient-other`.
- The policy evaluation shows `allowed_by=['practitioner-policy']` with `errors=[]`. So this is a clean false allow from a policy that evaluated without error, and the policy is named directly.
- The other three tests in `test_02_practitioner_consent.py` still pass, as do the search-leak, bypass and matrix suites. That argues against a broad change such as the policy becoming allow-all or losing its role check, and points to a narrow change that only affects the revoked case.

**Limit of the evidence:** the log doesn't show the policy body or the Consent resource. The policy id is directly evidenced, but the exact change is inferred from the test name and the pattern of passes. A related edit to the consent matching, such as a changed status value, would look the same.

**Decisive lines:**
- `E       AssertionError: expected deny for GET /fhir/Patient/bakeoff-adb77f1d-patient-other: allowed_by=['practitioner-policy'] errors=[]`
- `FAILED tests/test_02_practitioner_consent.py::test_revoked_consent_denies - A...`
- `========================= 1 failed, 64 passed in 1.86s =========================`

**Confidence:** medium (high for the policy id, medium for the exact change).

The count below is the single Read of the log and excludes this report's hand-off call.

TOOL_CALLS: 1
