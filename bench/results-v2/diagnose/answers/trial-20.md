**Root cause:** AccessPolicy `as-patient-read-own-condition` now contains invalid SQL. It is an SQL-engine policy, and Postgres rejects its statement with a syntax error at a literal `{`, at character position 99.

**What most likely changed:** The SQL's `{{...}}` parameter placeholder was probably broken, for example a malformed or single-brace form such as `{user...}` instead of `{{user...}}`. Aidbox would then not substitute it, and the raw brace would reach Postgres. The log does not show the SQL text, so the exact edit is an inference. It also cannot distinguish an edit to this policy from a newly added broken policy with this id.

**Why this policy:**
- All 20 failures are `pat-self` requests, and all 20 show this same single error entry with this id. No other policy id appears in `errors`.
- The policy runs on every `pat-self` request, whatever the path or method (Patient, Encounter, Observation, Bundle POST, Appointment, SDC), so it is evaluated for that identity and throws each time.
- p1, p2, receptionist, no-role and admin tests all pass, so the damage is limited to policy evaluation for the patient identity.
- Access decisions look unchanged. The expected grants match (`patient-role-policy`, `as-patient-read-own-encounter`, `as-patient-search-own-observations`) and deny cases show `granted: []`. Each test fails only on the `errors: []` part of the assertion, so this is a crashing policy rather than a change in who is allowed. Those assertions fail before the HTTP status is checked, so the log shows no response codes for these requests.

**Decisive lines:**
```
"error": "ERROR: syntax error at or near \"{\"
  Position: 99",
"id": "as-patient-read-own-condition",
```

**Confidence:** high on the policy id and on the failure being invalid SQL with a stray `{`. Medium on the specific edit being a broken `{{...}}` placeholder.

TOOL_CALLS: 1
