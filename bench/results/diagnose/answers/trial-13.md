**Root cause:** AccessPolicy `receptionist-role-policy` was over-broadened, so the receptionist role now gets access it should be denied.

**What most likely changed:** its request matcher was loosened, and the role check still works. The likeliest edit is that the resource/URI and `request-method` constraints were removed or widened, for example a matcho `uri` regex or method list that became permissive, leaving it close to a role-only allow.

The evidence for that:
- All 4 failures are the `rec` client on requests that should be denied, each with `allowed_by=['receptionist-role-policy']` and `errors=[]`. This is a clean allow, not a policy error.
- The wrongly allowed requests cross two axes:
  - Method on the same resource: PUT, JSON-patch PATCH and merge-patch PATCH on `/fhir/Patient/{id}`.
  - Resource type: GET on `/fhir/Encounter/{id}`.
- One narrow edit, such as adding a single method or a single resource, would not explain both axes. The change must have relaxed both, or removed a single constraint that covered both.
- The other clients still behave correctly: the `norole` tests (`test_05`) and the search-leak tests pass. The other 61 tests pass too, so the problem looks confined to this one policy.

**Limits of the output:** it does not show the policy body, so the exact edited field is inferred. `as-practitioner-sdc-consented-patient` appears in the dump only as not matching (`'reason': 'wrong role'`), so it is a bystander. In `test_json_patch_denied` the loop failed on `rec` first and never reached `p1`, so that test says nothing about `p1`.

**Decisive lines:**
- `E       AssertionError: expected deny for PUT /fhir/Patient/bakeoff-b2fc8019-patient-self: allowed_by=['receptionist-role-policy'] errors=[]`
- `E       AssertionError: expected deny for GET /fhir/Encounter/bakeoff-b2fc8019-enc-match: allowed_by=['receptionist-role-policy'] errors=[]`
- `E       AssertionError: expected deny for PATCH /fhir/Patient/bakeoff-b2fc8019-patient-self: allowed_by=['receptionist-role-policy'] errors=[]`

**Confidence:** high on the policy id and the direction (over-permissive); medium on the exact field changed.

TOOL_CALLS: 1
