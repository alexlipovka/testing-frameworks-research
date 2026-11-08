**Root cause:** AccessPolicy `as-receptionist-read-patients` most likely had its HTTP method constraint widened to allow `patch` as well as `get`. For example, `request-method` went from `get` to something like `{$enum/$one-of: [get, patch]}`. The policy is meant to be read-only, but it now grants PATCH on `/fhir/Patient/{id}` to the receptionist.

**Why this reading fits the output:**
- All 3 failures are the receptionist PATCHing a Patient: two JSON Patch, one merge-patch. They failed at the pre-flight check that expects no granting policies, and that check named exactly this policy each time.
- The grant covers more than one patient (`patient-self` and `patient-other`), so it isn't scoped to a particular record.
- Receptionist PUT, POST and transaction-Bundle writes are still denied, and `rec update: deny` passes. PUT uses the same URI as read, so the method check can't have been removed outright; only PATCH was added.
- Receptionist read and search still pass via the same policy, so its GET path is intact.
- Patient JSON Patch on their own record is still denied, and no other role or policy shows a change. The change is confined to this one receptionist policy.
- `v.errors` was empty (that assertion comes first and passed), so this is a real over-grant, not a crashing policy.

**Limits of the evidence:** the log doesn't show the policy body, so the exact form of the edit is inferred. It also doesn't show whether other methods, such as DELETE, were added, because no failing test covers them.

**Decisive lines:**
> `Error: granting policies on rec PATCH /fhir/Patient/bakeoff-ee82738c-patient-self`
> `+   "as-receptionist-read-patients",`
> `✓  13 tests/04-receptionist.spec.ts:16:3 › 4. receptionist reads but does not write Patients › deny: PUT a Patient (51ms)`

**Confidence:** high

TOOL_CALLS: 1
