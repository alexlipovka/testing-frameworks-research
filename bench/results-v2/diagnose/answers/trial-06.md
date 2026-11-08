**Root cause:** the AccessPolicy `receptionist-role-policy` was over-broadened, so it now grants the receptionist requests it used to deny. All 4 failures have the same signature: user `bakeoff-803008ff-rec`, an expected deny, `allowed_by=['receptionist-role-policy']` and `errors=[]`.

**What most likely changed:** the policy's request constraint was loosened or removed, on the HTTP method and/or the URI/resource-type match. The role match still holds. The newly allowed requests are:
- PUT `/fhir/Patient/{id}`
- PATCH `/fhir/Patient/{id}`, both merge-patch and json-patch
- GET `/fhir/Encounter/{id}`

Because these span both write methods and a second resource type, a single added method or resource is not enough to explain them. A dropped or widened method/URI restriction fits better. The log does not show the policy body, so the exact field is an inference.

The 63 passing tests suggest the grant may not be fully open, but the log doesn't list which other receptionist denials ran. I can't tell whether it is now a role-only allow.

No other policy appears in `allowed_by`. Nothing errored, so this is a false allow and not a policy-evaluation error. Other policies, such as `as-practitioner-sdc-consented-patient`, appear only as non-matching with `wrong role`.

**Decisive lines:**
- `E       AssertionError: expected deny for PUT /fhir/Patient/bakeoff-803008ff-patient-self: user=bakeoff-803008ff-rec allowed_by=['receptionist-role-policy'] errors=[]`
- `E       AssertionError: expected deny for PATCH /fhir/Patient/bakeoff-803008ff-patient-self: user=bakeoff-803008ff-rec allowed_by=['receptionist-role-policy'] errors=[]`
- `E       AssertionError: expected deny for GET /fhir/Encounter/bakeoff-803008ff-enc-match: user=bakeoff-803008ff-rec allowed_by=['receptionist-role-policy'] errors=[]`

**Confidence:** high on the policy id and on the direction (over-permissive). Medium on the nature of the change (method/URI constraint loosened), low on the exact field.

The count below is one Read plus this SubagentHandback call.

TOOL_CALLS: 2
