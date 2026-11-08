**Root cause:** AccessPolicy `as-patient-read-own-condition` now holds invalid SQL. Its engine is most likely `sql`, because the error is a raw Postgres parse error. The most likely edit is a broken parameter or template placeholder in the SQL text: a literal `{` at character 99 of the generated statement, where Aidbox should have substituted a value. Examples would be `{{user.fhirUser.id}}` with mangled delimiters or a malformed `{{...}}` expression. A stray or unbalanced brace in an edited `sql.query` would give the same error. The output does not show the SQL, so the exact form of the bad text is an inference.

**Why this policy and this kind of change:**
- All 17 failures have the same error, with the same policy id and `Position: 99`. They fail on the `expect(v.errors).toEqual([])` assertion, so the policy throws rather than simply denying.
- Every failure is a `pat-self` request, across GET, search, PUT, PATCH, POST, Bundle and SDC operations. The policy is evaluated for every patient-role request regardless of resource or method, so it crashes each time. The practitioner, receptionist and no-role identities all pass, so the problem is limited to the policy or policies linked to the patient role.
- The failures stop at the error assertion, before the `granted` and status checks run. The output therefore says nothing about whether allow/deny outcomes also changed. The fault is a policy evaluation error, not a shown change in access.

**Decisive lines:**
- `+     "error": "ERROR: syntax error at or near \"{\"`
- `+   Position: 99",`
- `+     "id": "as-patient-read-own-condition",`

**Confidence:** high on the policy id and on the failure being a SQL syntax error around `{`. Medium on the exact edit (a malformed template placeholder versus some other stray brace).

TOOL_CALLS: 1
