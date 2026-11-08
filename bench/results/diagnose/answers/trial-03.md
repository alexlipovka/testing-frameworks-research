**Root cause:** AccessPolicy `as-patient-read-own-condition` now has a broken SQL engine body. It most likely contains an unresolved or malformed template placeholder, or a literal `{`/JSON fragment, near character 99 of the generated SQL. An example would be a `{{...}}` parameter that is written wrongly and passed through to Postgres verbatim, such as a mangled `{{user...}}` substitution in the patient-match condition. The output doesn't show the policy body, so the exact token is inference. Every evaluation of the policy fails at parse time with a Postgres syntax error.

**Why this one policy:**
- All 12 failures involve the `pat-self` client and report the same single entry in `errors`, on unrelated endpoints: Patient read and search, Encounter, Observation search, batch Bundle, Appointment create and `$populate`.
- The other clients' requests pass (the practitioner, receptionist and norole test files are green), and the `rec` deny in `test_transaction_bundle_denied` passes before the `pat_self` assertion fails. That fits a policy that is only evaluated for the patient role, probably role-gated, with an error on every patient request.
- The authorization outcomes themselves are unchanged: `patient-role-policy` and `as-patient-read-own-encounter` still allow, and denied requests still have `allowed_by=[]`. Tests fail only because `v.errors` is non-empty. So this is a policy that throws, not a change that widened or narrowed access.

**Decisive lines:**
- Line 48: `E       AssertionError: expected allow for GET /fhir/Patient/bakeoff-2a128b36-patient-self: allowed_by=['patient-role-policy'] errors=[{'id': 'as-patient-read-own-condition', 'error': 'ERROR: syntax error at or near "{"\n  Position: 99'}]`
- Line 148: `E       AssertionError: expected deny for GET /fhir/Observation?subject=Patient/bakeoff-2a128b36-patient-other: allowed_by=[] errors=[{'id': 'as-patient-read-own-condition', 'error': 'ERROR: syntax error at or near "{"\n  Position: 99'}]`

**Confidence:** high on the policy id and the failure class (SQL syntax error from a stray or unsubstituted `{`). Medium on the exact edit, since the policy body is not in the output.

TOOL_CALLS: 2
