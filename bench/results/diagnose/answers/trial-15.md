**Root cause:** the policy `receptionist-role-policy` was most likely broadened, or added, so that it no longer restricts receptionists to what they could do at baseline. It now evaluates true on `GET /fhir/Patient/<id>`, alongside the expected `as-receptionist-read-patients`. The most likely specific change is that its constraint was loosened, probably a `request-method` or URI/resource restriction removed, so it now grants Patient access including writes. It is still role-bound as far as the output shows, since `05-norole-denied` passes.

**How the three failures connect:**
- **`04-receptionist-read-not-write`:** the debug output shows a second policy granting access where exactly one was expected. This is the only failure that names a policy.
- **`07-bypass`:** a `PATCH` on `patient-self` that must be denied returned 200, so write access has opened up. The output does not show which user sent this request. I am inferring it is the same over-grant.
- **`14-run-isolation`:** this is most likely a side effect of 07, not a separate fault. The search on `family:exact=Bakeoff` returns 2 of 3 patients, and only `patient-self` is missing, which is the record the wrongly allowed `PATCH` would have changed (presumably its family name).

**Decisive lines:**
- `|   actual:   list <[receptionist-role-policy,as-receptionist-read-patients]>`
- `35 | HTTP 403` with `|      ^^^ actual value is <200>` (the `PATCH {{url}}/fhir/Patient/{{run_id}}-patient-self` request in `07-bypass`)
- `|   actual:   list <[bakeoff-792b9ce0-patient-other,bakeoff-792b9ce0-patient-unlinked]>`

**Confidence:** high that `receptionist-role-policy` is the culprit and that the change is an over-grant. Medium on exactly which field changed, because the log does not show the policy body.

TOOL_CALLS: 1
