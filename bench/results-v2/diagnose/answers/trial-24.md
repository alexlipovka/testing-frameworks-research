**Root cause:** AccessPolicy `receptionist-role-policy` was over-broadened, so it now grants requests it should deny. All 4 failures have the same shape: user `rec`, expected deny, `granted=['receptionist-role-policy']`, `crashed=[]`.

**What most likely changed:** the policy's request constraint was loosened or removed, leaving something close to a role-only match (user is a receptionist, no effective limit on the request).
- The wrongly granted requests cross both boundaries: writes (`PUT` and `PATCH` on Patient), and reads of resource types outside its scope (`GET /fhir/Observation` search, `GET /fhir/Encounter/{id}`).
- A single allowed-method or single resource-type edit would not explain all four, so the method and URI/resource-type restriction was probably dropped together, for example a removed `uri`/`request-method` key in the matcho, or a broadened regex or `or` branch.
- The output does not show the policy body, so the exact field edited is inferred.

**Other signals:**
- It is not a policy crash or engine error, because `crashed=[]` and the decision is a clean grant.
- No other policy or role appears in any failure; the other 91 tests passed, so only the receptionist's deny boundary moved.
- The log does not show whether the grant is unlimited. Other receptionist denies, if the suite has any (DELETE, for example), passed or were not tested, so the loosening may be slightly narrower than fully open.

**Decisive lines:**
- `AssertionError: expected deny: user=bakeoff-7f54443c-rec PUT http://localhost:8280/fhir/Patient/bakeoff-7f54443c-patient-self?__debug=policy: granted=['receptionist-role-policy'] crashed=[]`
- `AssertionError: expected deny: user=bakeoff-7f54443c-rec GET http://localhost:8280/fhir/Observation?__debug=policy: granted=['receptionist-role-policy'] crashed=[]`
- `AssertionError: expected deny: user=bakeoff-7f54443c-rec GET http://localhost:8280/fhir/Encounter/bakeoff-7f54443c-enc-match?__debug=policy: granted=['receptionist-role-policy'] crashed=[]`

**Confidence:** high on the policy id and the direction (over-permissive); medium on the exact field changed.

TOOL_CALLS: 1
