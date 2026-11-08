**Root cause:** `practitioner-policy` was most likely loosened, so its Consent-based Patient read rule no longer scopes access to the specific patient requested.

**What the output shows**
- 1 of 93 tests failed, and it failed in the permissive direction. Practitioner `p1` reading `patient-other` should be denied, but the `__debug: policy` decision was granted, and the grant is attributed to `practitioner-policy`.
- No other test failed, so this is not a broad break. Nothing went wrong that would suggest a policy was removed, a role was broken, or a client or engine setting changed. A narrow over-grant on one negative case fits a single weakened condition.

**What most likely changed (inference)**
The log does not show the policy body or a diff. The best fit is that the check tying the Consent to the requested Patient was dropped or weakened. For example, the check became "p1 has some active Consent" rather than "a Consent exists for this patient and p1". A less likely variant is that a different Consent condition was relaxed, such as status or period, if `patient-other` has a non-qualifying Consent. The log can't distinguish these, because it doesn't show what Consent data `patient-other` has.

**Decisive lines**
- `AssertionError: expected deny, granted by ['practitioner-policy']`
- `FAILED tests/test_02_practitioner_consent.tavern.yaml::practitioner reads Patient via Consent[p1-patient-other-deny-403]`
- `1 failed, 92 passed in 7.73s`

**Confidence:** high that `practitioner-policy` is the policy at fault, medium on the exact condition that changed. Overall: medium.

TOOL_CALLS: 1
