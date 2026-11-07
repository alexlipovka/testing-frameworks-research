# Mutant set

Each directory is one known-bad change to the baseline policies
(`../policies/`). Its `*.yaml` files replace or add to the baseline, and
`probe.json` is one request whose verdict the mutant changes. A suite
**kills** a mutant when at least one of its tests fails with the mutant
applied. The kill rate is the Failure diagnostics measurement in the spec.

```sh
./apply.sh 05-revoked-consent-counts   # baseline with this mutant swapped in
./revert.sh                            # baseline only
./check.sh lint                        # offline: every mutant is well formed and changes something
./check.sh live                        # every probe's verdict differs from the baseline's (~30 s)
```

Both scripts refuse while a fixture run is open (a teardown would delete
the policies), so a kill run is: apply, then the suite's own setup, tests and
teardown, then the next mutant. See a mutant with
`diff -u ../policies/<file> <dir>/<file>`.

`check.sh live` only proves each mutant is killable. It is not a suite and
says nothing about which suite kills what.

## Mutants

01–08 are ported from the lab (`hurl-emr-lab`, step 9), adapted to this
baseline. In the lab, 05 survives by design until the learner writes its
test; here the spec's case 2 covers it, so a complete suite kills all 15.
09–15 are new and cover known pain points.

| Mutant | The bug | A real-world cause | Probe: baseline → mutant |
|---|---|---|---|
| 01 allow-all-is-back | `patient-role-policy` is `engine: allow` again | a revert; an Aidbox restart re-applying fhir-emr's init bundle | pat-self reads patient-other: deny → allow |
| 02 r5-consent-subject | joins on `Consent.subject` | R5 renamed `Consent.patient` | p1 reads patient-self: allow → deny |
| 03 any-not-every | `_id=a,b` passes when *some* id is consented | the obvious query | p1 searches `_id=self,other`: deny → allow |
| 04 role-name-typo | `roleName: practitoner` | a typo: the policy silently never applies | p1 reads patient-self: allow → deny |
| 05 revoked-consent-counts | drops `status = 'active'` | "simplifying" the query | p1 reads patient-other: deny → allow |
| 06 include-guard-dropped | receptionist Patient read has no `_include` guard | included resources skip policy checks | rec `Patient?_revinclude=Observation:subject`: deny → allow |
| 07 encounter-type-unchecked | own-Encounter SQL drops the resource type check | a plain `sql` policy runs on every request of its role | pat-self reads `Observation/<enc-match id>`: deny → allow |
| 08 encounter-any-id | drops `id = {{params.resource/id}}` | "any of my Encounters" | pat-self reads enc-mismatch: deny → allow |
| 09 silent-sql-deny | own-Encounter SQL compares `subject.reference`, which is null in storage | FHIR-format path on Aidbox-format rows: no error, no rows | pat-self reads enc-match: allow → deny |
| 10 single-braces-masked | adds a Condition policy with `{role.links.patient.id}` | single braces reach Postgres as-is and the policy crashes on every patient request, while other policies still answer | pat-self reads own Patient: allow → allow + `error` |
| 11 scope-drift | receptionist Appointment policy loses `resource/type` | "generalising" a policy | rec reads obs-match: deny → allow |
| 12 seed-id-hardcoded | practitioner SQL compares to `'practitioner1'` | pasted from a session against the demo seed | p2 reads patient-other: allow → deny |
| 13 patch-bypass | receptionist Patient policy denylists `post`/`put`/`delete` | a denylist that forgets `PATCH` (JSON Patch and merge-patch) | rec JSON-Patches patient-self: deny → allow |
| 14 role-name-dropped | receptionist Patient policy has no `roleName` | a global policy: every login gets it | norole searches Patient: deny → allow |
| 15 forged-answer-accepted | `$extract` no longer checks `patientId` answers against the QR subject | trusting a hidden form field | p1 extracts a QR for patient-self that writes to patient-other: deny → allow |

Only 10 changes no status code. A suite kills it only by asserting that no
policy crashed (`$.policies[?(@.error)]` empty) on a patient request: spec
case 3.
