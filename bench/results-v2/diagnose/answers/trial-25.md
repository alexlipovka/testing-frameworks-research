**Root cause:** AccessPolicy `as-patient-read-own-condition` now has invalid SQL. It is evidently a SQL-engine policy, and its SQL fails in Postgres with `syntax error at or near "{"` at position 99.

**What most likely changed:** a template placeholder in the policy's SQL was malformed, so a literal `{` reached Postgres. For example, Aidbox's `{{user.…}}` / `{{params.…}}` may have lost a brace or been otherwise broken, leaving it unsubstituted. The log doesn't show the policy body, so the exact edit is inferred from the error text.

**Supporting evidence:**
- All 25 failures (25 failed, 70 passed) are for user `pat-self`, and every one I read has this same crashed policy and error. No other policy id ever appears as crashed.
- The crash shows up on every `pat-self` request regardless of resource or method: Patient, Encounter, Observation, Appointment, Bundle, PATCH and `$extract` / `$populate`. So this policy is evaluated for all of that user's requests, and it fails at SQL execution rather than on a bad match.
- Other decisions look unaffected: `patient-role-policy`, `as-patient-read-own-encounter` and `as-patient-search-own-observations` are still granted where expected, and deny cases show `granted=[]`. Those tests fail only on the `assert not _crashes(pols)` guard.
- The one real functional effect is that `pat-self` reading its own Condition (`fhir/Condition/bakeoff-5d815081-cond-match`) now shows `granted=[]`, because the policy that should allow it crashes.

**Decisive lines:**
- Line 214: `AssertionError: a policy crashed: user=bakeoff-5d815081-pat-self GET http://localhost:8280/fhir/Condition/bakeoff-5d815081-cond-match?__debug=policy: granted=[] crashed=[{'id': 'as-patient-read-own-condition', 'error': 'ERROR: syntax error at or near "{"\n  Position: 99'}]`
- Line 99: `AssertionError: expected allow, a policy crashed: user=bakeoff-5d815081-pat-self GET http://localhost:8280/fhir/Patient/bakeoff-5d815081-patient-self?__debug=policy: granted=['patient-role-policy'] crashed=[{'id': 'as-patient-read-own-condition', 'error': 'ERROR: syntax error at or near "{"\n  Position: 99'}]`

**Confidence:** high on the policy id and on a SQL syntax break from a stray `{`; medium on the exact edit being a malformed placeholder.

The count below is two Read calls plus this hand-off.

TOOL_CALLS: 3
