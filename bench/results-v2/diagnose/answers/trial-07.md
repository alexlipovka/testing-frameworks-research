**Root cause:** AccessPolicy `as-receptionist-read-patients` most likely had `'patch'` removed from the HTTP methods its SQL engine excludes. The receptionist's read-only policy now allows PATCH on Patient.

The policy's `and` trace passes both checks, and the SQL check now reads `? NOT IN ('post', 'put', 'delete')`, bound to `patch`. PUT, POST and DELETE are still listed, so PATCH is the odd one out. The baseline was almost certainly `NOT IN ('post', 'put', 'patch', 'delete')`, or an equivalent. The baseline text is not in the log, so that part is inferred.

**How the failures fit this one change:**
- `04-receptionist-read-not-write` and `07-bypass` fail because a receptionist's PATCH returns 200 instead of 403, with both JSON Patch and merge-patch. `as-receptionist-read-patients` is the only policy with `eval-result: true` on those requests. `receptionist-role-policy` evaluates false because it expects `Appointment`.
- The GET checks in those two files then find `family` is `Hacked`, because the write really happened.
- `14-run-isolation` is a knock-on failure. `patient-self` no longer has the family name `Bakeoff`, so the search returns 2 entries instead of 3. It says nothing further about the policy.

**Decisive lines:**
1. `"id":"as-receptionist-read-patients"` trace entry (log lines 15 and 121): `{"eval-result":true,"query":["SELECT ? NOT IN ('post', 'put', 'delete')\n  AND coalesce(?, '') !~* '(^|&)(_|%5f)(rev)?include'\n","patch","__debug=policy"]}`
2. `jsonpath "$.policies[?(@['eval-result'] == true)].id" not exists` with `actual:   string <as-receptionist-read-patients>` (lines 22-23)
3. `55 | HTTP 403` with `^^^ actual value is <200>` (lines 49-50, on `PATCH {{url}}/fhir/Patient/{{run_id}}-patient-self`)

**Confidence:** high

The count below covers the one Read of the log and excludes this hand-off call.

TOOL_CALLS: 1
