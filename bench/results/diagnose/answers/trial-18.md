**Root cause:** AccessPolicy `as-patient-read-own-condition` now contains invalid SQL, so it crashes on evaluation. Postgres rejects it with `syntax error at or near "{"` at position 99.

**What most likely changed:** the policy's SQL body. A literal `{` is reaching Postgres, which suggests a malformed or unsubstituted `{{...}}` template placeholder, for example a broken parameter such as `{{user.data...}}` with a mangled brace or path. The output doesn't include the SQL text, so the exact edit is inferred. It also can't show whether this policy was edited or newly added.

**Evidence**
- All 15 failures are `pat-self` scenarios, across 6 features (01, 03, 06, 07, 08, 09). Each reports this same policy id and error.
- 14 fail on `match r.crashed == []`. The other is the 08-matrix `pat-self` row, which fails on `match wrong == []`, and its four entries list the same crash.
- Authorization outcomes for the patient still look right. The matrix shows the expected decision each time: `want ["patient-role-policy"], got ["patient-role-policy"] status 200` and `want [], got [] status 403`. So the regression is the policy erroring during evaluation, not a wrong grant or deny in these checks.
- Scenarios for the other users in those features did not fail. The policy is hit even on Patient reads, PATCH and transaction requests, so it is evaluated for all `pat-self` requests, not only Condition reads. That fits a policy tied to the patient role or user.

**Decisive lines**
```
[{"id":"as-patient-read-own-condition","error":"ERROR: syntax error at or near \"{\"\n  Position: 99"}]
```
```
"read: want [\"patient-role-policy\"], got [\"patient-role-policy\"] status 200 crashed [{\"id\":\"as-patient-read-own-condition\",\"error\":\"ERROR: syntax error at or near \\\"{\\\"\\n  Position: 99\"}]"
```

**Confidence:** high on the policy id and that its SQL is syntactically broken. Medium on the specific cause being a malformed `{{...}}` placeholder.

The count below is 2 Reads of the log plus this handback.

TOOL_CALLS: 3
