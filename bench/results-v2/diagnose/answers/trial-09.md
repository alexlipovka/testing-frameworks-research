**Root cause:** AccessPolicy `as-patient-read-own-encounter` no longer grants a patient read of their own Encounter. The policy id comes from the test's `policy` parameter, because the failing decision itself lists no policies.

**What most likely changed:** its allow condition now evaluates to false without an error, for the legitimate case of `pat-self` doing `GET /fhir/Encounter/<own id>`. The most likely form is a tightened or altered ownership match, such as the patient/subject reference comparison, or a matcher field that no longer fits this request.

The output supports the following:
- **Not a crash:** `crashed=[]` rules out a malformed policy that errors or throws during evaluation (e.g. SQL or policy errors). The evaluation ran and simply granted nothing.
- **Narrow scope:** 2 of 95 tests failed, and both are the same case (`pat-self` on `enc-match`), once in `test_01` and once in `test_08_matrix`. The other 93 passed, including everything else in the matrix, so this isn't a broad auth or patient-session break.
- **Over-permission (a change that widens access):** no deny expectation failed. The observed direction is a lost allow, not a leak.

The output can't show the exact edit. These would all look the same here: a changed ownership path or operator, a changed method/URI matcher, a changed `link` or engine, or the policy being deleted or disabled. No policy body or diff appears in the log.

**Decisive lines:**
- `AssertionError: expected allow: user=bakeoff-60288352-pat-self GET http://localhost:8280/fhir/Encounter/bakeoff-60288352-enc-match?__debug=policy: granted=[] crashed=[]`
- `policy = 'as-patient-read-own-encounter'`
- `2 failed, 93 passed in 3.30s`

**Confidence:** high on which policy and on the symptom (a silent non-match, not a crash); low to medium on the specific field that changed. Tool-call count below is the one Read of the log, excluding this hand-off.

TOOL_CALLS: 1
