**Root cause:** the policy is `receptionist-role-policy`. Its resource/URI scope was most likely widened, so it now matches `/fhir/Patient...` for the receptionist (`rec`).

**What the output shows**
- It now allows `rec` to do PUT (200), POST (201) and PATCH (200) on Patient. GET and search on Patient also list it, next to the expected `as-receptionist-read-patients`.
- The role binding looks intact. Every failed verdict is `who: rec`, and the patient, practitioner and no-role features all pass (01, 02, 05).
- No policy crashed (`crashed: []` throughout), so this is an over-grant, not a broken policy.
- `POST /fhir` for bundles still returned 403 in the runs I could see, though the log doesn't name the user on those lines. That fits a `/fhir/...`-style pattern rather than a total removal of the matcher, but it's weak evidence.

**Inference, not shown directly:** the output never prints the policy body.
- The `rec` matrix row flags only read, search and update. Its Appointment create (201, thread virtual-63, identified by request pattern) wasn't flagged, so that policy was probably scoped to Appointment before.
- Whether it was a URI or `resource` matcher, and whether a method restriction was loosened too, can't be determined. DELETE on Patient by `rec` isn't exercised either.

**Collateral failures, same cause**
- `14-run-isolation`: the stray server-assigned Patient `01a1bcb6-585a-...` is most likely from `rec`'s POST that should have been denied.
- `04` and `07` "left the Patient as it was" / "none of the attempts changed the Patient": the denied writes actually landed, so `given` became `Changed` / `X`.

**Decisive lines**
- `{"who":"rec","request":"POST /fhir/Patient","allowedBy":["receptionist-role-policy"],"crashed":[],"status":201}`
- `{"who":"rec","request":"PUT /fhir/Patient/bakeoff-9e6ade22-patient-self","allowedBy":["receptionist-role-policy"],"crashed":[],"status":200}`
- `["read: want [\"as-receptionist-read-patients\"], got [\"receptionist-role-policy\",\"as-receptionist-read-patients\"] status 200","search: want [\"as-receptionist-read-patients\"], got [\"receptionist-role-policy\",\"as-receptionist-read-patients\"] status 200","update: want [], got [\"receptionist-role-policy\"] status 200"]`

**Confidence:** high on the policy id, medium on the exact change (scope widened to Patient).

The count below is the 3 Read calls and excludes this hand-off.

TOOL_CALLS: 3
