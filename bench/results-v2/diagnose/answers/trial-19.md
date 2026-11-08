**Root cause:** the AccessPolicy `as-patient-read-own-encounter` no longer grants a patient read access to their own Encounter. It now fails to allow the legitimate case, so this is an over-restriction.

**What most likely changed:** its matching condition (the engine/matcho or SQL check, or its link to the patient role) was altered so it no longer matches `GET /fhir/Encounter/<own id>` for the patient user. For example, the patient/subject comparison may now point at the wrong path or value, or the resource/operation scope may have been narrowed.

- **Policy evaluates without error:** `crashed: []` means no SQL or evaluation crash, so it simply returned false or was not applied.
- **Deletion can't be ruled out:** the output cannot separate a changed condition from the policy being deleted or unlinked, because all of these give `allowedBy: []` and 403. The output does not show the policy body or the actual diff.
- **Narrow blast radius:** 90 of 91 scenarios pass, and the only failure is "pat-self on Encounter: own Encounter allows". Patient's own-record reads on other resources pass, and the Encounter-mismatch denial still holds, which fits a change confined to this one policy.

**Decisive lines:**
- `- pat-self on Encounter: own Encounter allows`
- `* match r.verdict contains { allowedBy: ['as-patient-read-own-encounter'], crashed: [], status: 200 }`
- `{"who":"pat-self","request":"GET /fhir/Encounter/bakeoff-29d911c5-enc-match","allowedBy":[],"crashed":[],"status":403}`

**Confidence:** high on the policy id; low to medium on the exact nature of the change.

The count below is two Read calls plus this handback.

TOOL_CALLS: 3
