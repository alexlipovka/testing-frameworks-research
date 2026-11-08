**Root cause:** AccessPolicy `as-patient-read-own-condition` now contains malformed SQL. It is most likely an `engine: sql` policy whose SQL text was edited so that a literal `{` reaches Postgres, about 99 characters into the statement. The likeliest form is a broken or unsubstituted `{{...}}` placeholder, such as a mangled `{{user...}}` patient-id reference, or a single-brace typo. The output shows the policy id and the Postgres error, but not the SQL itself, so the exact edit can't be determined.

**Evidence:**
- All 20 failing scenarios (6 of 14 features: 01, 03, 06, 07, 08, 09) fail the same way: the `crashed` array holds this one policy id and this one error, where `[]` was expected.
- Status codes and `allowedBy` match expectations in every failure. For example, own Patient is still 200 via `patient-role-policy` and other Patient is still 403. So there is no access regression. The only thing the suite detects is the evaluation crash.
- Every failure has `who: pat-self`. Practitioner, receptionist and no-role features (02, 04, 05) pass, which suggests the policy is only evaluated for the patient role, consistent with its name.
- The log shows no `Condition` read after setup, only the fixture `PUT` of `cond-match`. So the logged requests never exercise this policy's intended allow path, and the output can't confirm whether own-Condition access actually broke. A SQL error there would mean it no longer grants.

**Decisive lines:**
1. `{"who":"pat-self","request":"GET /fhir/Patient/bakeoff-3b069e8c-patient-self","allowedBy":["patient-role-policy"],"crashed":[{"id":"as-patient-read-own-condition","error":"ERROR: syntax error at or near \"{\"\n  Position: 99"}],"status":200}`
2. `$.crashed | not equal | actual array length is not equal to expected - 1:0 (LIST:LIST)`
3. `scenarios:  91 | passed:   71 | 20 failed`

**Confidence:** high on the policy id and on a SQL syntax break at `{`; medium on the precise edit being a malformed template placeholder.

The count below is 2 Reads of the log plus this handback.

TOOL_CALLS: 3
