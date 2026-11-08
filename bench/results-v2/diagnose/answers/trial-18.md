**Root cause:** the AccessPolicy `as-receptionist-read-patients` now also allows the HTTP `PATCH` method on Patient. It should be read-only (GET read and search). Most likely its request-method constraint was widened to include `patch`, for example from `get` to `$one-of: [get, patch]`.

**Evidence:**
- All 3 failures are receptionist `PATCH /fhir/Patient/<id>` requests: JSON Patch and merge-patch, on both patient-self and patient-other. In each one the policy decision shows this policy granting a request that should have had no grants.
- The grant does not depend on which patient is targeted or on the patch content type, so this is a method-level widening rather than a change to an id or patient-scoping condition.
- It is limited to PATCH. Receptionist PUT, POST, Bundle writes (`deny: PUT a Patient`, `deny: POST a Patient`, `rec update: deny`, assuming that matrix case is a PUT) and `_include`/`_revinclude` searches are still denied, so the policy was not opened up to all methods and no method constraint was removed outright.
- Receptionist reads and searches still pass via this same policy.
- Other roles are unaffected, for example `deny: patient JSON-Patches own record` passes. No policy errors appear (`errors: []`), so the failures are a wrong allow rather than a crash.

**Decisive lines:**
```
Error: decision on rec PATCH /fhir/Patient/bakeoff-938eac46-patient-other
+     "as-receptionist-read-patients",
✓  16 tests/04-receptionist.spec.ts:16:3 › 4. receptionist reads but does not write Patients › deny: PUT a Patient (47ms)
```

**Confidence:** high on the policy id and that PATCH is now allowed. Medium on the exact edit, because the output does not show the policy body.

TOOL_CALLS: 1
