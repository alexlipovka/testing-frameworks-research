**Root cause:** AccessPolicy `as-receptionist-read-patients`, which should give the receptionist (`rec`) read-only access to Patient, now also allows PATCH on Patient. Most likely its request-method constraint was widened, for example from `get` to get + patch (or a patch branch or link was added).

**Evidence:**
- All 4 failures trace to this one change. Three are "rec PATCH ... denied" scenarios (JSON Patch, merge-patch, and the plain PATCH in feature 04). In each, the `__debug=policy` verdict shows `status: 200`, allowed by that policy.
- The fourth failure ("the denied writes left the Patient as it was", `['X']` instead of `['Self']`) is a side effect: the PATCH really was applied and changed the name.
- The widening looks PATCH-specific. The other scenarios in feature 04 passed (5 of 7), and the log shows 403s on `PUT /fhir/Patient/...-patient-self` and `POST /fhir/Patient` around those runs. The log doesn't label which user made each request, so this rests mainly on those scenarios passing.
- The output does not show the policy body, so the exact edit is inferred from behaviour. It could be a method matcher change or a separate added PATCH allow in the same policy. Whether DELETE is also opened can't be confirmed from the log.

**Decisive lines:**
- `{"who":"rec","request":"PATCH /fhir/Patient/bakeoff-f938574b-patient-self","allowedBy":["as-receptionist-read-patients"],"crashed":[],"status":200}`
- `- rec PATCH on Patient is denied`
- `$[0] | not equal (STRING:STRING)` with `'X'` vs `'Self'` (the patch was persisted)

**Confidence:** high for the policy and that it now permits PATCH; medium for the exact form of the edit.

TOOL_CALLS: 2
