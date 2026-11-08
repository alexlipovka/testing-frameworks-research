**Root cause:** AccessPolicy `as-patient-read-own-condition` now contains invalid SQL. Its SQL check most likely has a malformed or unsubstituted template placeholder. For example, a `{{...}}` user or fact interpolation (probably the patient reference) may have lost a brace or otherwise been corrupted, so a literal `{` reaches Postgres at character 99 of the generated statement. The log does not show the policy body, so the exact placeholder is inferred.

**Evidence:**
- All 15 failures carry the identical error from this one policy, and no other policy id appears with an error.
- All 15 failures are for user `pat-self`. `test_other_roles_denied` fails only for its `pat-self` parameter in this log, not for `rec`, `norole` or `p2`. This suggests the role guard still works and the SQL only runs for the patient role.
- The error appears on requests unrelated to Condition (Patient, Encounter, Observation, Appointment, a batch Bundle, `$populate`). So the policy's SQL runs for patient-role requests generally.
- Allow and deny decisions are unchanged: expected allows are still `allowed_by` the right policy, and expected denies have `allowed_by=[]`. The tests fail only because `v.errors` is non-empty, so this is a policy evaluation error, not a change in who gets access.

**Decisive lines:**
- `E       AssertionError: expected allow for GET /fhir/Patient/bakeoff-cbe552d6-patient-self: user=bakeoff-cbe552d6-pat-self allowed_by=['patient-role-policy'] errors=[{'id': 'as-patient-read-own-condition', 'error': 'ERROR: syntax error at or near "{"\n  Position: 99'}]`
- `E       AssertionError: expected deny for GET /fhir/Observation/bakeoff-cbe552d6-enc-match: user=bakeoff-cbe552d6-pat-self allowed_by=[] errors=[{'id': 'as-patient-read-own-condition', 'error': 'ERROR: syntax error at or near "{"\n  Position: 99'}]`

**Confidence:** high on the policy id and on the fault being broken SQL with a stray `{`. Medium on the specific edit being a mangled template placeholder.

The count below covers the single Read and excludes this hand-off call.

TOOL_CALLS: 1
