**Root cause:** AccessPolicy `as-patient-read-own-condition` now crashes when Aidbox evaluates it. It most likely received a malformed edit to its evaluation logic. The file name `test_03_sql_policy_error` suggests a `sql`-engine policy whose query now errors at runtime, for example a syntax error, a bad column or path, or a bad cast. This is an inference: the log never shows the policy body, its engine, or the underlying SQL or error text, so the exact edit can't be determined.

**Evidence:**
- All 22 failures (71 passed) have the same assertion, naming this one policy. It comes from the crash guard in `helpers.py` (`decision` line 19, `no_crash` line 58).
- All 22 are `pat-self` requests, across unrelated resources and operations: Patient, Encounter, Observation search, Appointment, Bundle, PATCH, and SDC `$populate`/`$extract`. A policy named for Condition is therefore being evaluated, and crashing, on every `pat-self` request, not only Condition reads. No other user's test fails, which points to a policy scoped to that patient user or role.
- No failure reports a wrong allow/deny decision or a wrong status. In `decision`, the crash check is the assertion that fired, so the log shows no sign of a changed grant or scope. A broken policy fits this pattern better than a widened or narrowed one.

**Decisive lines:**
- `AssertionError: policies crashed: ['as-patient-read-own-condition']`
- `FAILED tests/test_03_sql_policy_error.tavern.yaml::no baseline policy crashes for pat-self[fhir/Condition/bakeoff-53d23f69-cond-match]`
- `22 failed, 71 passed in 7.68s`

**Confidence:** high for the policy id; medium for the nature of the change (a broken evaluation expression, probably SQL).

The count below is 2 Reads of the log plus this handback.

TOOL_CALLS: 3
