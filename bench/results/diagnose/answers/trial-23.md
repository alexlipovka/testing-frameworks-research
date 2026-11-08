**Root cause (most likely):** the AccessPolicy that gates Practitioner reads of Patient resources on consent or relationship was loosened. A practitioner can now read a Patient they should be denied. The condition most likely removed or widened is the consent check on `GET /fhir/Patient/{id}`.

**Policy id:** the output does not show one. The log has no policy names, so a practitioner read/consent policy is inferred from the test file name (`02-practitioner-consent`) and the failing request. I can't give the exact id or the exact edit. It could be a dropped consent clause, a matcher broadened to any patient, or an added allow scoped to the practitioner role.

**Why this and not something broader:**
- The failure is a false allow (200 where 403 was expected), so a rule got more permissive. A lost grant or a broken policy would show the opposite.
- 12 of 13 files pass, including `05-norole-denied`, `04-receptionist-read-not-write`, `07-bypass`, `01-patient-own-record` and `03-sql-error-not-deny`. A global or public allow would likely have tripped the no-role, receptionist or bypass cases, so the change looks scoped to the practitioner path.
- `06-search-leak` also passes. If that file covers practitioner search, the change may be limited to read-by-id, but the log doesn't show what it covers.

**Decisive lines:**
- `--> cases/02-practitioner-consent.hurl:21:6`
- `GET {{url}}/fhir/Patient/{{run_id}}-patient-other`
- `21 | HTTP 403` with `actual value is <200>`

**Confidence:** medium that it is the practitioner consent/patient-read policy and that it was loosened; low on the exact id and the exact change.

The count below covers the one Read of the log and excludes this handback.

TOOL_CALLS: 1
