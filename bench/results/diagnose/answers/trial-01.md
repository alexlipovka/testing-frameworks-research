**Root cause:** AccessPolicy `as-receptionist-read-patients` now also matches PATCH on Patient. It was most likely widened from read-only to allow PATCH, for example by loosening or adding to its `request-method` / HTTP-method constraint (such as `get` becoming a set that includes `patch`, or the method check being removed).

**Evidence:**
- Both failures are the same case: the receptionist (`rec`) sends PATCH to `/fhir/Patient/{run_id}-patient-self`, the test expects deny, and the `__debug: policy` output names this one policy as the grant.
- A read-scoped policy granting a write points to the policy's method matcher, not to a new or wrong-role policy.
- It fails for both `application/json-patch+json` and `application/merge-patch+json`, so the change is about the method and not one patch content type.
- The other 91 tests pass, including all other roles and, as far as the output shows, the receptionist's reads and everything outside this PATCH case. So the policy's link to the receptionist and the Patient resource appears intact, and the change is narrow.

**Limits of the output:**
- The output doesn't show the policy body, so the exact edited field is inferred.
- Tavern stops a test at its first failing stage, so any stages after "JSON Patch decision" in `rec cannot write Patient` did not run. The log therefore can't rule out other methods also being opened if they are only checked after that stage. Stages before it, and the other passing tests, show no such grant.

**Decisive lines:**
- `AssertionError: expected deny, granted by ['as-receptionist-read-patients']`
- `FAILED tests/test_04_receptionist.tavern.yaml::rec cannot write Patient`
- `FAILED tests/test_07_bypass.tavern.yaml::PATCH bypass is denied[rec-application/merge-patch+json-{'name': [{'family': 'Merged'}]}]`

**Confidence:** high on the policy id and on PATCH being wrongly granted; medium on the exact mechanism (method matcher widened).

The count below is the one Read of the log plus this hand-off.

TOOL_CALLS: 2
