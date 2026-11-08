# Bench results (ticket 08)

Host: Intel i5-7300HQ (4 cores), 31 GB RAM, Linux 7.2 (zen), Docker 29.9.3. One stack, one suite at a time.
Suite versions: as committed in `suites/` at the time of each commit below; the Karate suite is measured without the tuned rows of case 1 (user decision).

## LOC (`loc.sh`)

cloc 1.98 (pinned by digest), every git-tracked file under `suites/<name>/` including runners and Dockerfiles, minus docs (`*.md`) and dependency lockfiles (`package-lock.json`, `requirements.txt`). cloc has no Hurl language, so `bench/hurl.lang` defines one (`#` comments); Hurl's `matrix/table.txt` counts as Hurl. Per case: files are mapped by their number prefix (Hurl `matrix/*` = case 8); everything else is `shared` (helpers, fixtures, runners, config).

| Suite | Total | AP cases 1–9 | per AP case | Cases 10–15 | Case 8 (matrix) | Shared |
|---|---|---|---|---|---|---|
| Hurl | 527 | 378 | 42.0 | 128 | 26 | 21 |
| Karate | 609 | 292 | 32.4 | 201 | 37 | 116 |
| pytest | 418 | 185 | 20.6 | 91 | 20 | 142 |
| Playwright | 699 | 315 | 35.0 | 170 | 38 | 214 |
| Tavern | 725 | 421 | 46.8 | 183 | 39 | 121 |

Raw: `loc.csv` (suite × case), `loc-by-file.csv`. Hurl has no case-15 file: its runner runs the suite twice (`RUNS=2`, in `shared`). The other four have a case-15 file that checks for residue inside one run; spec (updated case 15) says only the runner-level double run counts, so those files measure effort spent, not conformance.

## Mutant kill matrix (`mutants.sh`, `mutants_report.py`)

Each suite in its native mode (Hurl `--jobs 4`, Karate 4 threads, Playwright 4 workers, pytest and Tavern sequential). Per mutant × suite:

1. `revert.sh`, then check that no run is open: no runner state file and no `bakeoff-*` rows in the main tables (pytest keeps its tx stamp only in memory, so the row count is the only check that covers it).
2. Baseline run.
3. `apply.sh <mutant>`, run twice.
4. Run the **decision-ablated** copy (`ablate.sh`: every `__debug=policy` assertion deleted, status and body assertions kept) once.
5. `revert.sh` and the open-run check again.

Failing tests come from each runner's JUnit XML (Hurl reports per file; Hurl matrix rows from its log). **Killed** = some test fails in both mutant runs and is not a known flake (a test that failed in a baseline run). **●** = killed only by a policy-decision assertion: the ablated copy shows no such failure.

| Mutant | Hurl | Karate | pytest | Playwright | Tavern |
|---|---|---|---|---|---|
| 01 allow-all-is-back | ✓ | ✓ | ✓ | ✓ | ✓ |
| 02 r5-consent-subject | ✓ | ✓ | ✓ | ✓ | ✓ |
| 03 any-not-every | ✓ | ✓ | ✓ | ✓ | ✓ |
| 04 role-name-typo | ✓ | ✓ | ✓ | ✓ | ✓ |
| 05 revoked-consent-counts | ✓ | ✓ | ✓ | ✓ | ✓ |
| 06 include-guard-dropped | ✓ | ✓ | ✓ | ✓ | ✓ |
| 07 encounter-type-unchecked | ✗ | ✗ | ✗ | ✗ | ✗ |
| 08 encounter-any-id | ✓ | ✗ | ✗ | ✗ | ✗ |
| 09 silent-sql-deny | ✓ | ✗ | ✓ | ✗ | ✓ |
| 10 single-braces-masked | ● | ● | ● | ● | ● |
| 11 scope-drift | ✓ | ✓ | ✓ | ✓ | ✓ |
| 12 seed-id-hardcoded | ✓ | ✓ | ✓ | ✓ | ✓ |
| 13 patch-bypass | ✓ | ✓ | ✓ | ✓ | ✓ |
| 14 role-name-dropped | ✓ | ✓ | ✓ | ✓ | ✓ |
| 15 forged-answer-accepted | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Killed** | **14/15** | **12/15** | **13/15** | **12/15** | **13/15** |
| killed only by a decision assertion | 1 (10) | 1 (10) | 1 (10) | 1 (10) | 1 (10) |

Survivors, from the test code:

- **07** (pat-self reads `Observation/<enc-match id>`): no suite sends a request with an Encounter id under another type. Karate's removed tuned rows were this request.
- **08** (pat-self reads `enc-mismatch`): only Hurl asserts that deny (case 3).
- **09** (silent SQL deny on pat-self's own Encounter): Karate has no allowed own-Encounter read (also in the removed rows). Playwright's pat-self reads of `enc-match` / `enc-mismatch` are only in case 3, which asserts no crash but no decision.

Every kill except 10 is also made by a status or body assertion. Mutant 10 changes no status code, so only a "no policy crashed" assertion catches it, and all five suites have one.

Raw: `mutants.csv` (300 runs: run, exit code, failing tests), `mutant-matrix.csv` (verdicts, killing tests, notes), `mutants/<mutant>/<suite>-{mutant1,mutant2,ablated}.log` (baseline logs kept only when red).

### Flakes

- **Karate case 14** (`every Bakeoff Patient on the server is this run's`) is flaky under 4 threads. It failed in 3/15 baselines, 9/30 mutant runs and 11/15 ablated runs. Features 04, 08, 10 and 13 create Patients with family `Bakeoff` and delete them later; case 14's `family=Bakeoff` search, running in parallel, sometimes sees one. It is excluded from kill decisions. The three red baselines (before 02, 11 and 15) were this test alone.
- **Karate 04** (`the denied writes left the Patient as it was`) failed in one of the two mutant-11 runs only. It doesn't affect the verdict: mutant 11 is killed by other tests in both runs.
- No other suite had a red baseline or two mutant runs that disagreed.

## Runtime (`runtime.sh`)

hyperfine 1.19.0, 10 runs per suite and mode, one at a time. Every run is a fresh container, so runner startup is included in both conditions. **Warm**: after one untimed run. **Cold**: Aidbox restarted before each run (the restart is not timed), so cold minus warm is the cost of a cold Aidbox, not of the runner. **Floor**: a no-op start of each runner image; Karate's floor is `java -version` on the base JRE, so it excludes loading Karate itself. pytest and Tavern have no parallel mode (spec).

Mean seconds:

| Suite | Floor | Seq warm | Par warm | Seq cold | Par cold |
|---|---|---|---|---|---|
| Hurl | 0.23 | 2.57 | 2.45 | 3.30 | 3.05 |
| Karate | 0.25 | 5.28 | 4.85 | 6.53 | 6.00 |
| pytest | 0.88 | 3.05 | n/a | 3.80 | n/a |
| Playwright | 1.10 | 6.29 | 4.81 | 7.13 | 6.00 |
| Tavern | 0.43 | 8.52 | n/a | 9.47 | n/a |

Parallelism saves 5% (Hurl), 8% (Karate) and 24% (Playwright) warm. Standard deviation is at most 0.30 s in every cell. Karate par warm exited non-zero in 3 of 10 runs; every other cell was 0 of 10. hyperfine keeps no output for those runs, so the failing test is not recorded. The rate is in line with the case-14 flake above, but that is not confirmed.

Raw: `runtime.csv`, `runtime/*.json`.

## Time-to-diagnose (`diagnose_prep.sh`)

Mutants 05, 09, 10, 11, 13 × 5 suites = 25 trials, shuffled under neutral names. Each suite's first mutant-run log, with ANSI colours stripped, went to a fresh agent (Opus 5.5, prompt in `diagnose/prompt.txt`) that could read only that file. The agent transcripts confirm each one read only its own log and used no other tool. Karate and Playwright never killed mutant 09, so those two trials have no failure to diagnose and were not run: 23 trials ran.

Answers were graded against the mutant diffs on two axes. **Policy**: `id` = named the mutated policy by id; `area` = only its role or purpose. **Change**: `right` = names what changed; `partly` = right kind of fault but cause not pinned down or not the lead theory; `wrong` = neither. The grades are the author's reading of each answer and await the user's spot-check.

| Suite | Trials | Policy by id | Change right | Change partly | Reads per trial |
|---|---|---|---|---|---|
| Hurl | 5 | 1 | 2 | 3 | 1.0 |
| Karate | 4 | 4 | 4 | 0 | 2.0 |
| pytest | 5 | 4 | 4 | 1 | 1.0 |
| Playwright | 4 | 4 | 4 | 0 | 1.0 |
| Tavern | 5 | 4 | 2 | 3 | 1.2 |

Per trial (policy / change):

| Mutant | Hurl | Karate | pytest | Playwright | Tavern |
|---|---|---|---|---|---|
| 05 revoked-consent-counts | area / partly | id / right | id / right | id / right | id / partly |
| 09 silent-sql-deny | area / partly | not killed | area / partly | not killed | area / partly |
| 10 single-braces-masked | area / partly | id / right | id / right | id / right | id / partly |
| 11 scope-drift | id / right | id / right | id / right | id / right | id / right |
| 13 patch-bypass | area / right | id / right | id / right | id / right | id / right |

No answer was wrong. Reads is the audited count of Read calls; it follows log length (Karate logs run about 70 KB and were read in two parts), and the agents' self-reported `TOOL_CALLS` lines are inconsistent about counting the hand-back. Turns are nearly constant, so correctness separates the suites more than effort does. Karate and Playwright's perfect rows exclude 09, the hardest mutant here, because they never detected it: read this table together with the kill matrix.

Hurl names a policy id only where a test asserts the granting policies and that assertion fails (mutant 11). Tavern's helpers print the granted ids but drop the error text, which is why 10 is only partly diagnosed there. None of the 09 logs show the SQL, so no suite can reveal the mutated column.

Raw: `diagnose/trials.csv` (trial → mutant, suite, killed), `diagnose/answers/`, `diagnose/grades.csv`, `diagnose/audit.csv`, `diagnose/<mutant>/<suite>.log`.

## Known items, reported and left unchanged

- Hurl case 8 (`matrix/matrix.hurl`) asserts status only, not the policy decision of each cell.
- Karate (`p.error != null`) and Hurl (`?(@.error)`) test that `error` is present, not that it is non-empty.
