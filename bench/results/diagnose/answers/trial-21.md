**Root cause:** the AccessPolicy `practitioner-policy` (the SQL Consent check for practitioner reads) most likely lost its Consent status filter. The `status = 'active'` predicate was probably removed or loosened, so a revoked Consent now counts as a grant.

**Reasoning:**
- Only 1 of 75 tests failed: "deny: p1 on a patient whose Consent is revoked". The verdict shows `practitioner-policy` granting p1 GET /fhir/Patient/bakeoff-d2953e84-patient-other, where no policy should grant.
- The rest of the Consent check still works, which rules out a broad change:
  - The practitioner match holds: "deny: p2 on a patient consented only to p1" passes.
  - The requirement that a Consent exists holds: "deny: nobody is consented to the unlinked patient" passes, as does "p2 read: deny" in the matrix.
  - The allow paths for active Consents pass.
- The policy did not crash. The failure is an unwanted grant, and the `v.errors` assertion just before it passed.
- The only condition specific to the failing case is the Consent's revoked state.

The log shows the policy id but not its SQL, so the exact edit is inferred. It could be a dropped status check or a widened one, such as `status != 'x'` or an added `'revoked'` value.

**Decisive lines:**
- `✘   5 tests/02-practitioner-consent.spec.ts:12:3 › 2. practitioner via Consent (SQL) › deny: p1 on a patient whose Consent is revoked (42ms)`
- `Error: granting policies on p1 GET /fhir/Patient/bakeoff-d2953e84-patient-other`
- `+   "practitioner-policy",`

**Confidence:** high

TOOL_CALLS: 1
