**Root cause:** AccessPolicy `practitioner-policy` most likely lost the part of its Consent check that requires an active Consent, such as `Consent.status = 'active'`. It now appears to accept any Consent linking the practitioner to the patient, so p1's revoked Consent on patient-other (fixture `bakeoff-aa0fbfea-consent-p1-other-revoked`) grants read access.

**Evidence:**
- 90 of 91 scenarios passed. The only failure is "p1 reads patient-other: revoked Consent denies".
- The output names `practitioner-policy` as the policy that allowed the request, and the status was 200 instead of 403.
- The policy was widened, not broken: `crashed` is empty, and the other 13 features all passed, including patient, receptionist, no-role, SQL-throws and bypass.
- The rest of the Consent check seems intact. `02-practitioner-consent` still passed its other 4 scenarios, and two lines fit that: patient-unlinked returned 403 (line 453), and a practitioner-style read of patient-self returned 403 (line 448), which I take to be p2, who has no Consent there.
- That 403 is what argues against a dropped actor/practitioner match, since p1's Consent on patient-self would otherwise have let p2 in. The log doesn't show who sent each request, so this part is inferred.

**Limit:** the log doesn't show the policy body, so the exact changed clause is inferred. The policy id comes directly from the output.

**Decisive lines:**
- `- p1 reads patient-other: revoked Consent denies`
- `{"who":"p1","request":"GET /fhir/Patient/bakeoff-aa0fbfea-patient-other","allowedBy":["practitioner-policy"],"crashed":[],"status":200}`
- `$.allowedBy | not equal | actual array length is not equal to expected - 1:0 (LIST:LIST)`

**Confidence:** high for the policy, and high overall that the revoked-status check was lost (the exact clause wording is inferred).

The count below is my two Read calls and excludes this hand-back.

TOOL_CALLS: 2
