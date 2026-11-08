Root cause: the AccessPolicy `practitioner-policy` (the SQL policy that grants practitioners access through Consent) most likely lost or weakened its Consent status check. It should only match `status = 'active'`, but it now also matches a revoked Consent, either because the status predicate was removed or because it was widened to include `revoked`.

Reasoning:
- The only failure of 77 tests is "deny: p1 on a patient whose Consent is revoked". The decision dump shows `practitioner-policy` granting p1 on `patient-other`, with `errors: []`, so the SQL runs cleanly and returns true rather than crashing.
- The rest of the Consent logic still works, which narrows the change to the status check:
  - Practitioner match: "deny: p2 on a patient consented only to p1" passes.
  - Consent must exist: "deny: nobody is consented to the unlinked patient" passes.
  - Active-Consent allows still pass.
  - An always-true policy, or a dropped actor or patient join, would have failed those denies too.
- No other role's tests or SDC tests changed, and the grant names exactly one policy.
- The log does not show the policy body, so the exact edit is inferred from which tests passed and failed.

Decisive lines:
- `2. practitioner via Consent (SQL) › deny: p1 on a patient whose Consent is revoked`
- `Error: decision on p1 GET /fhir/Patient/bakeoff-3393030e-patient-other`
- `+     "practitioner-policy",`

Confidence: high (certain on the policy id, inferred on the exact predicate change).

The count below covers the file read and excludes this hand-off call.

TOOL_CALLS: 1
