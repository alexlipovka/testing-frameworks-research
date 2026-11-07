# Shared fixtures

Every suite in `suites/*/` loads `fixtures.json` and follows this contract.
How a suite does it natively is part of what the bake-off scores
(Fixtures / isolation). `run.sh` is the reference in curl + jq.

```sh
./run.sh lint     # offline shape check
./run.sh check    # live: setup, 5 tokens, teardown, no residue; twice
```

## Identities

| Name | User | Role | Linked to |
|---|---|---|---|
| `pat-self` | `{{run_id}}-pat-self` | patient | `Patient/{{run_id}}-patient-self` |
| `p1` | `{{run_id}}-p1` | practitioner | `Practitioner/practitioner1` (seed) |
| `p2` | `{{run_id}}-p2` | practitioner | `Practitioner/practitioner2` (seed) |
| `rec` | `{{run_id}}-rec` | receptionist | `Practitioner/receptionist` (seed) |
| `norole` | `{{run_id}}-norole` | none | none |

Each gets a bearer token from `POST /auth/token` (password grant) through
the run's own `{{run_id}}-client`.

## Fixtures

| Fixture | Belongs to | Purpose |
|---|---|---|
| `patient-self` | pat-self | match |
| `patient-other` | nobody in the run | mismatch |
| `patient-unlinked` | nobody, no Consent | unlinked |
| `enc-match` / `enc-mismatch` | patient-self / patient-other | match / mismatch |
| `obs-mismatch` | patient-other | search leak target (case 6) |
| `obs-match`, `cond-match`, `appt-match` | patient-self (appt also has practitioner1) | clinical data the wrong roles must not see |
| `consent-p1-self` | active: p1 sees patient-self | Consent allow |
| `consent-p2-other` | active: p2 sees patient-other | Consent allow |
| `consent-p1-other-revoked` | inactive: p1 on patient-other | revoked Consent must still deny (case 2) |

All ids are `{{run_id}}-<name>`. The demo seeds are only referenced, never
modified. SDC cases (9) use the seeded `Questionnaire/glucose` and build
their QuestionnaireResponses per test.

## The run

1. **run_id**: generate a fresh `bakeoff-<random>`, then replace every
   `{{run_id}}` in `fixtures.json` with it. The token is exactly
   `{{run_id}}`; `lint` rejects any other spelling.
2. **Stamp**: run `sql.install` (installs `drop_before_all`), then
   `sql.stamp`, as admin through `POST /$psql`. Keep the result as `tx_id`.
   Record it *before* the first write, so a setup that fails halfway can
   still be torn down.
3. **Setup**: send each `setup[]` entry in order as admin (`method`,
   `path`, JSON `body`). Each must succeed.
4. **Tokens**: one per identity, stored under its `token_var`.
5. **Teardown**: replace `{{tx_id}}` in `sql.rollback` with the stamp and
   run it. It deletes every row written after the stamp, in every table,
   including Sessions and resources with server-generated ids. It always
   runs, even when tests fail.

Rules that follow from the stamp:

- **One run at a time per stack.** A teardown deletes everything after its
  own stamp, including another run's rows. Parallelism happens inside a
  run, not between runs.
- **Change AccessPolicies between runs, never during one.** A teardown
  would delete them.
- `*_history` tables are skipped, as in the lab: updates made during a run
  leave history rows behind. Nothing reads them.
- A runner that loses its `tx_id` leaves the run behind. `run.sh` writes
  it to `.vars` (`FIXTURES_VARS`) before the first fixture for that reason.
