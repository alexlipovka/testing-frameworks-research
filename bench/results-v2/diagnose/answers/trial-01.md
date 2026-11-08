**Root cause:** `receptionist-role-policy` now grants the receptionist role everything. Its request-matching constraint is effectively gone, so the only thing it still checks is the role and the `_include`/`_revinclude` SQL guard.

**Evidence from the log**
- It evaluates `true` for the receptionist on every request type in the log: FhirRead and FhirSearch on Patient, FhirUpdate, FhirCreate, FhirPatch (JSON and merge patch), and FhirRead on Encounter.
- Its first `trace` entry is `{"eval-result":true}` with no errors each time. The only other entry is the include-blocking SQL check.
- `as-receptionist-read-patients` looks intact. It has the same two-part shape, but still rejects writes with `expected "One of FhirRead, FhirSearch"` and `expected "get"`, and rejects Encounter with `expected "Patient"`. So the access comes from the other policy, not from this one being loosened.
- The real requests went through when they should have returned 403: PUT and PATCH returned 200, POST returned 201, and GET Encounter returned 200.
- The role gate still works. `norole`, `p1`, `p2` and `pat-self` all pass, so only the receptionist is affected.
- The failures in `04-receptionist-read-not-write` and `07-bypass` are this same over-grant. `14-run-isolation` is collateral: it found no `patient-self` with family `Bakeoff` because the receptionist's writes had renamed that patient to `Hacked`.

**What the output can't settle:** whether the policy was newly added as a role-wide allow, or was an existing narrow policy whose operation, method or resource-type matcher was removed. In both cases the baseline did not have it matching these requests, because the suite expected `as-receptionist-read-patients` to be the only passing policy.

**Decisive lines**
```
  actual:   list <[receptionist-role-policy,as-receptionist-read-patients]>
```
```
  actual:   string <receptionist-role-policy>
```
(line 48, on the PUT that should match no policy; the same appears on POST, PATCH and GET Encounter)
```
29 | HTTP 403
     |      ^^^ actual value is <200>
```

**Confidence:** high on the policy id and the over-broad matcher; the added-versus-edited question stays open.

The count below covers the five Read calls and excludes this hand-off.

TOOL_CALLS: 5
