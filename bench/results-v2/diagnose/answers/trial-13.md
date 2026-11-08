**Root cause:** AccessPolicy `as-patient-read-own-encounter` no longer grants the patient's read of their own Encounter. The policy stopped matching a request it should allow, so this is an over-restriction, not a leak.

**What most likely changed:** its matcho engine match was narrowed or broken so the legitimate request fails. The output can't tell which part of the match changed. Candidates are:
- the Encounter/patient ownership condition, such as the `subject` reference or the user-to-patient link path
- the operation or URI matcher for `GET /fhir/Encounter/{id}`
- the role or client condition
- the policy being deleted or renamed, which would produce the same output

**Why this policy:**
- Exactly 1 of 77 tests failed, `allow: own Encounter`, and it names this policy as the expected grant.
- The decision came back with nothing granted and no errors, so no policy crashed. The request simply matched nothing. That points away from a SQL or evaluation failure.
- `pat-self` is otherwise fine: `allow: own Patient` and the matrix `pat-self read: allow via patient-role-policy` both pass. The patient identity, role and the separate `patient-role-policy` are intact.
- All deny tests pass, including another patient's Encounter and an Encounter id under another resource type. Nothing was widened.

**Decisive lines:**
- `Error: decision on pat-self GET /fhir/Encounter/bakeoff-15ee1e2c-enc-match`
- `-     "as-patient-read-own-encounter",`
- `+   "granted": Array [],`

**Confidence:** high on which policy, and that it became too restrictive or stopped applying. Low on the exact field that changed.

TOOL_CALLS: 1
