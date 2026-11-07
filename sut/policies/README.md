# Baseline AccessPolicies

The policy set every suite tests against, and the set every mutant in
`../mutants/` breaks. fhir-emr ships `engine: allow` for each role; files
that keep an upstream id (`patient-role-policy`, `practitioner-policy`,
`receptionist-role-policy`) replace it.

```sh
../mutants/revert.sh     # install the baseline (also after Aidbox restarts)
```

Aidbox re-applies fhir-emr's init bundle on start, which puts the upstream
`engine: allow` policies back. Run `revert.sh` after every `docker compose up`.
Like any policy change, only between runs: a teardown deletes policies
written during its run, so `apply.sh` and `revert.sh` refuse while one is open.

## What each identity may do

Identities and fixtures are in `../fixtures/README.md`. Anything not listed
is denied, including transaction Bundles (`POST /fhir`) for every role.

| Identity | Allowed | Policy |
|---|---|---|
| `pat-self` | read own `Patient` by id | `patient-role-policy` (matcho) |
| | read an `Encounter` by id whose subject is their Patient | `as-patient-read-own-encounter` (sql) |
| | search `Observation?subject=` exactly their Patient (`Patient/<id>` or `<id>`), no includes | `as-patient-search-own-observations` |
| `p1`, `p2` | read a `Patient` by id with an active Consent naming them | `practitioner-policy` |
| | search `Patient?_id=a,b,…` when every id has such a Consent, no includes | `as-practitioner-search-consented-patients` |
| | `$populate` / `$extract` on a Questionnaire for such a Patient; for `$extract` every `patientId` answer must equal the QuestionnaireResponse `subject` | `as-practitioner-sdc-consented-patient` |
| `rec` | read and search `Patient`, no includes; no `PUT`, `POST`, `PATCH` | `as-receptionist-read-patients` |
| | create, read, search, update, patch, delete `Appointment`, no includes | `receptionist-role-policy` |
| `norole` | nothing | |

So, with the fixtures: `p1` sees `patient-self` (active Consent) but not
`patient-other` (revoked); `p2` sees `patient-other` but not
`patient-self`; nobody's Consent covers `patient-unlinked`.

General FHIR cases (10–13) run as admin (`root:secret`, basic auth), which
upstream's `admin`/Client policies already allow.

## Facts the policies rely on (Aidbox 2608.8)

- `$populate` / `$extract` are sdc App operations, ids
  `POST.app.aidbox.utils.wrap.fhir_Questionnaire___id___dpopulate` /
  `..._dextract`. The policy sees the request `body` in FHIR format
  (`subject.reference: "Patient/<id>"`), while stored rows are in Aidbox
  format (`subject.id`).
- SQL policies can read `{{body}}::jsonb`, `{{request-method}}` (lower case)
  and `{{operation.id}}`. A JSON path into the body (`{{body.a.b}}`) without
  a cast fails with "could not determine data type".
- A repeated search param (`subject=a&subject=b`) arrives as a JSON array.
