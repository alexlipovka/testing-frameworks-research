**Root cause:** an AccessPolicy now throws an error when it is evaluated. The most likely change is that its SQL engine body (or the `sql` matcher) was broken, for example invalid SQL, a bad column or JSON path, or a bad parameter. The grant logic itself probably wasn't narrowed or widened.

**Policy id:** the output does not show one. The log only reports that `$.policies[?(@.error)]` matched an object, and it doesn't print that object. Beyond this point I'm inferring from test names and paths:
- The best candidate is the SQL policy behind patient and own-record access, evaluated on Patient reads (`{{run_id}}-patient-self`).
- It is also evaluated on Encounter reads (`{{run_id}}-enc-match`), so it is either one policy covering both resource types or one whose compartment or match SQL reaches both.
- The name `03-sql-error-not-deny` suggests this test exists to catch a policy SQL error that would otherwise look like an ordinary deny.

**Why this rather than a changed permission:**
- Both failures are the same assertion, on the `?__debug=policy` request, at line 14 of each file. Neither failure output shows a status-code mismatch or a wrong-body assertion.
- The other 11 files pass, including 02 practitioner-consent, 04 receptionist, 05 norole-denied, 06 search-leak and 07 bypass. So allow/deny behaviour looks intact for those roles, and there is no sign of a leak or lost access.
- Those passing files may simply not check `?__debug=policy` for errors, so the log can't prove that only one policy is affected.

**Decisive lines:**
```
--> cases/03-sql-error-not-deny.hurl:14:0
| GET {{url}}/fhir/Patient/{{run_id}}-patient-self?__debug=policy
14 | jsonpath "$.policies[?(@.error)]" not exists
```

**Confidence:** high that a policy evaluation error is the failure, medium that the cause is broken SQL in a SQL-engine policy, and low on which specific policy, since no id is shown.

TOOL_CALLS: 1
