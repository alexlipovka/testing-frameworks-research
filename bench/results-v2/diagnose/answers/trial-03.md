**Root cause:** the policy is `as-patient-read-own-encounter`, the SQL-engine policy that lets a patient read their own Encounter. Its ownership predicate was most likely changed so it can no longer match.

The predicate now reads `resource#>>'{subject,reference}' = 'Patient/' || ?`. Aidbox stores references in its internal format as `subject: {id, resourceType}`, so `{subject,reference}` should be NULL on stored rows. The baseline was probably `resource#>>'{subject,id}' = ?`, with the patient id compared directly. The result is an over-restriction: a patient is denied their own Encounter.

**Evidence:**
- Only 3 of 18 files fail: `cases/03-sql-error-not-deny.hurl`, `cases/01-patient-own-record.hurl` and `matrix/.gen/pat-self.hurl`.
- All three fail on the same two requests, for user `pat-self` on `Encounter/...-enc-match`: no policy evaluates true in the `__debug=policy` response, and the real GET returns 403 instead of 200.
- All deny-side and other-role files still pass, including the search-leak, bypass and `p1`/`p2`/`rec` matrix files. That fits a grant being narrowed, not a change to any shared policy.
- The other policies in the debug output fail for expected reasons, such as wrong resource type or operation, no links, or wrong role. `as-patient-read-own-encounter` is the only one that targets this request.
- It reports `eval-result: null` with no errors, and the SQL is well formed. So the query appears to have run and returned no rows, which reads as a silent deny, not a SQL error.
- The bound parameters are correct (`Encounter`, the `enc-match` id, the `patient-self` id), and so are the table and the type and id clauses. That leaves the subject comparison as the only suspect.

**Decisive output lines:**
1. `"query":["SELECT true\nFROM encounter\nWHERE ? = 'Encounter'\n  AND id = ?\n  AND resource#>>'{subject,reference}' = 'Patient/' || ?","Encounter","bakeoff-a8032ca2-enc-match","bakeoff-a8032ca2-patient-self"],"id":"as-patient-read-own-encounter"` (fragment of log line 16, `eval-result` null)
2. `jsonpath "$.policies[?(@['eval-result'] == true)].id" == "as-patient-read-own-encounter"` followed by `actual:   none`
3. `14 | HTTP 200` with `^^^ actual value is <403>`

**Confidence:** high on the policy and on the subject-match clause being the fault. Medium on the exact before and after, because the log does not show the baseline text and the storage-format explanation comes from my knowledge of Aidbox, not from this output.

I made one Read call; the count below excludes this hand-back.

TOOL_CALLS: 1
