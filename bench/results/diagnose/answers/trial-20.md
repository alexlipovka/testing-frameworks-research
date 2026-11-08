**Root cause:** AccessPolicy `receptionist-role-policy` was widened so it now grants the receptionist write access to Patient (PUT, POST and PATCH, including merge-patch). In the baseline it should only have covered the receptionist's Appointment work; Patient reads come from a separate policy, `as-receptionist-read-patients`. The most likely edit is a broadened resource-type or URI match, or an added Patient/write branch, in its allow rule. The output doesn't show the policy body, so the exact field is inferred.

**Evidence:**
- All 6 failures are "rec" writes on `/fhir/Patient`, and each one names `receptionist-role-policy` as the only granting policy. They fail at the `v.granted` check, and `v.errors` was empty just before it, so the policy matches cleanly and this is not a SQL or policy crash.
- The widening looks specific to Patient rather than a blanket allow. These receptionist denials still pass: writing a Patient inside a transaction Bundle, `$populate` and `$extract`, and `_include`/`_revinclude` pulls.
- All other roles (patient, p1/p2 practitioners, no-role) are unaffected, as are the receptionist's allowed reads and Appointment creation.
- The log shows no receptionist DELETE test, so I can't tell whether DELETE was opened too.

**Decisive lines:**
- `Error: granting policies on rec PUT /fhir/Patient/bakeoff-48f1931a-patient-self`
- `+   "receptionist-role-policy",`
- `✓  47 tests/08-matrix.spec.ts:35:7 › 8. matrix: 5 identities × 4 operations on patient-self › rec create-appointment: allow via receptionist-role-policy (42ms)`

**Confidence:** high on the policy id and on the effect (it now grants receptionist Patient writes); medium on the exact field changed.

The count below is 1 Read plus this hand-off call.

TOOL_CALLS: 2
