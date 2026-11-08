**Root cause:** AccessPolicy `as-patient-read-own-condition` now contains invalid SQL, so it fails with a Postgres syntax error instead of evaluating. It is a sql-engine policy linked to the patient role. The most likely edit is a broken parameter placeholder, specifically the last one, comparing the subject id to the session patient: for example `{{...}` with a closing brace dropped, or `{...}` instead of `{{...}}`.

**Evidence**
- This is the only policy in the debug output with an `error` field. It shows `eval-result: null` and no `query`, on every patient-token request, including Patient reads and a PUT. That means the SQL fails regardless of request parameters.
- The sibling policy `as-patient-read-own-encounter` still evaluates normally (`true` on the matching encounter).
- All 12 assertion failures are the same check, "no policy has an `.error`". They occur only in the 3 files that use the patient token: `cases/03-sql-error-not-deny.hurl`, `cases/01-patient-own-record.hurl` and `matrix/.gen/pat-self.hurl`.
- No status-code or access assertion failed. The other roles skip this policy ("wrong role"), so their files pass.

**Why the last placeholder (inference):** this assumes the Condition policy has the same shape as the Encounter one, and `condition` and `Condition` are the same length as `encounter` and `Encounter`. With `?` sent as `$1`, `$2`, `$3`, the third parameter starts at character 99, exactly where the error points. The literal `{` is sitting where a bound value should be, so this is not the `'{subject,id}'` JSON path, which starts around character 81.

**Decisive output** (lines 15 and 22-23 are from the first failure; line 15 is a fragment)
- Line 15: `{"eval-result":null,"id":"as-patient-read-own-condition","error":"ERROR: syntax error at or near \"{\"\n  Position: 99","policy-id":"as-patient-read-own-condition",...`
- Line 22: `10 | jsonpath "$.policies[?(search(@.error, '.'))].error" not exists`
- Line 23: `|   actual:   string <ERROR: syntax error at or near "{"`

**Confidence:** high on the policy and the failure class (malformed SQL). Medium on the exact placeholder detail, since the log never prints this policy's SQL.

The count below is the four Read calls and excludes this handback.

TOOL_CALLS: 4
