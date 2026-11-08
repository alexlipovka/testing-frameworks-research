**Root cause:** AccessPolicy `as-receptionist-read-patients` most likely had its allowed HTTP methods widened so that it now matches PATCH on `/fhir/Patient/{id}`. It should be read-only. The likely form is `request-method` changing from get-only to something that includes `patch`, such as a `$one-of`/enum entry.

**Why this policy:**
- The server's `__debug=policy` report names it as the only granting policy on the denied requests, and `crashed=[]` rules out a policy evaluation error.
- Only 2 of 95 tests failed. Both are the receptionist (`rec`) sending PATCH to `Patient/{run_id}-patient-self`, one as `application/json-patch+json` and one as `application/merge-patch+json`.
- Both content types being granted points to the HTTP method rather than to anything specific to the patch format.

**Why PATCH only, rather than the whole method constraint being removed (inferred):**
- If the constraint had been dropped, I would expect more receptionist write and bypass tests to fail. The other 93 tests passed, including the rest of the `test_07_bypass` cases.
- The log does not show the policy body or the earlier stages of "rec cannot write Patient", so I can't see the exact edit or confirm which methods those stages covered.

**Decisive lines:**
```
AssertionError: expected deny: user=bakeoff-0ee752b0-rec PATCH http://localhost:8280/fhir/Patient/bakeoff-0ee752b0-patient-self?__debug=policy: granted=['as-receptionist-read-patients'] crashed=[]
FAILED tests/test_07_bypass.tavern.yaml::PATCH bypass is denied[rec-application/merge-patch+json-{'name': [{'family': 'Merged'}]}]
2 failed, 93 passed in 3.33s
```

**Confidence:** high on the policy id, medium-high on PATCH being added to its allowed methods.

TOOL_CALLS: 1
