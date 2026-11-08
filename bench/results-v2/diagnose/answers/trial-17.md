**Root cause:** `receptionist-role-policy` was widened so that it now authorizes write operations on Patient. It most likely held the receptionist's Appointment-management grant, and that grant's resource-type restriction was loosened, either by adding Patient to the allowed types or by dropping or broadening the Appointment-only URI/resource match.

**Evidence from the log:**
- All 6 failures are receptionist Patient writes, and all have the same signature: the decision check expected `granted: []` but got `["receptionist-role-policy"]`, with `errors: []`. The failing calls are PUT, POST, JSON Patch and merge-patch.
- The `errors` array is empty, so the policy evaluates cleanly. This is an over-grant, not a crash or SQL error.
- The grant still has limits:
  - `rec read` and `rec search` still pass, attributed to `as-receptionist-read-patients`.
  - `rec create-appointment` still passes via `receptionist-role-policy`.
  - Other receptionist denials still pass: write inside a transaction Bundle, `$populate`/`$extract`, and the `_include`/`_revinclude` searches.
  - No other role is affected.
- So this looks like a targeted widening of the write grant's resource scope onto Patient, rather than the policy becoming allow-everything.

**What the output cannot show:** the policy body is not in the log. The suite only tests receptionist writes against Patient and Appointment, so I cannot tell whether Patient alone was added or whether other resource types were opened too. The passing `$populate`/`$extract` and Bundle denials suggest it is not a blanket allow on every `/fhir` POST.

**Decisive lines:**
- `Error: decision on rec PUT /fhir/Patient/bakeoff-c24c79e7-patient-self`
- `+     "receptionist-role-policy",`
- `✓  50 tests/08-matrix.spec.ts:35:7 › 8. matrix: 5 identities × 4 operations on patient-self › rec create-appointment: allow via receptionist-role-policy (38ms)`

**Confidence:** high on the policy id and on the effect (Patient writes now granted to the receptionist); medium on the exact field that changed.

Tool calls: one Read of the log, plus this handback.

TOOL_CALLS: 2
