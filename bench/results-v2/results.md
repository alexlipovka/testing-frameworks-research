# Bench results v2 (ticket 18)

Best-state suites, measured with the same protocol as `../results/results.md`. Same host (Intel i5-7300HQ, 4 cores, 31 GB RAM), one stack, one suite at a time. No suite was edited.

Changes to the bench:

- Output goes to `results-v2/` (`RESULTS`).
- pytest and Tavern now have a parallel mode, `-n 4`.
- `open_runs` also lists pytest's `reports/open-run.json`.
- `ablate.sh` was rewritten for the revised assertions and writes to `.ablated-v2`.
- A red baseline is retried up to twice and every attempt is recorded, so each mutant starts from green.
- A failed Aidbox start is retried, then stops the bench (see Runtime).

## LOC (`loc.sh`)

Same method as v1: cloc 1.98, every tracked file under `suites/<name>/`, including runners, minus docs and lockfiles.

| Suite | Total | AP cases 1–9 | per AP case | Cases 10–15 | Case 8 (matrix) | Shared |
|---|---|---|---|---|---|---|
| Hurl | 569 | 421 | 46.8 | 128 | 28 | 20 |
| Karate | 567 | 267 | 29.7 | 182 | 37 | 118 |
| pytest | 478 | 194 | 21.6 | 83 | 23 | 201 |
| Playwright | 695 | 324 | 36.0 | 159 | 38 | 212 |
| Tavern | 766 | 447 | 49.7 | 166 | 39 | 153 |

Against the first draft (`loc-added.csv`). Net code is the cloc difference. Git lines are raw additions and removals since the first-draft commit, comments included.

| Suite | First draft | Best state | Net code | Git lines added | Git lines removed |
|---|---|---|---|---|---|
| Hurl | 527 | 569 | +42 | 178 | 123 |
| Karate | 609 | 567 | −42 | 37 | 79 |
| pytest | 418 | 478 | +60 | 138 | 52 |
| Playwright | 699 | 695 | −4 | 16 | 19 |
| Tavern | 725 | 766 | +41 | 126 | 70 |

## Mutant kill matrix (`mutants.sh`, `mutants_report.py`)

Each suite in native parallel mode (Hurl `--jobs 4`, Karate 4 threads, Playwright 4 workers, pytest and Tavern `-n 4`). Per mutant × suite: green baseline, mutant run twice, decision-ablated copy once. **Killed** = some test fails in both mutant runs and is not a known flake. **●** = killed only by a policy-decision assertion.

The ablated copies of all five suites were green at baseline before the matrix started.

### Held-out mutants (the effectiveness measure)

Twelve mutants written after the revisions by a context that had not read the suites, in `sut/mutants-holdout/`.

| Mutant | Hurl | Karate | pytest | Playwright | Tavern |
|---|---|---|---|---|---|
| h01 | ✗ | ✗ | ✗ | ✗ | ✗ |
| h02 | ✗ | ✗ | ✗ | ✗ | ✗ |
| h03 | ✗ | ✗ | ✗ | ✗ | ✗ |
| h04 | ✓ | ✓ | ✓ | ✓ | ✓ |
| h05 | ✓ | ✓ | ✓ | ✓ | ✓ |
| h06 | ✓ | ✓ | ● | ✓ | ● |
| h07 | ✓ | ✗ | ✓ | ✗ | ✓ |
| h08 | ✓ | ✓ | ✓ | ✓ | ✓ |
| h09 | ✗ | ● | ● | ● | ● |
| h10 | ● | ● | ● | ● | ● |
| h11 | ✗ | ● | ● | ● | ● |
| h12 | ● | ● | ● | ● | ● |

| Suite | Killed | Killed only by a decision assertion |
|---|---|---|
| Hurl | 7/12 | 2 |
| Karate | 8/12 | 4 |
| pytest | 9/12 | 5 |
| Playwright | 8/12 | 4 |
| Tavern | 9/12 | 5 |

### Original 15 mutants

All five suites killed all 15. Mutant 10 is the only one killed by a decision assertion alone, in every suite.

| Suite | Killed | Killed only by a decision assertion |
|---|---|---|
| Hurl | 15/15 | 1 (10) |
| Karate | 15/15 | 1 (10) |
| pytest | 15/15 | 1 (10) |
| Playwright | 15/15 | 1 (10) |
| Tavern | 15/15 | 1 (10) |

The full per-mutant table is in `mutant-table.md`. The revisions were written with the first-draft survivors known, so 15/15 does not measure effectiveness. The held-out set does.

Raw: `mutants.csv`, `mutant-matrix.csv`, `mutants/` and the same files under `holdout/`.

### Flakes

No baseline was red in 27 × 5 = 135 baseline runs, so no retry was needed. No run was missing its report.

The one disagreement is Karate on mutant 13: `07-bypass-attempts › none of the attempts changed the Patient` failed in only one of the two mutant runs. It does not change the verdict, because other tests kill mutant 13 in both runs. Flakes are computed per set: a flake seen only in one set is not excluded from the other.

## Runtime (`runtime.sh`)

hyperfine 1.19.0, 10 runs per suite and mode, one at a time, with the same warm, cold and floor conditions as v1. Mean seconds:

| Suite | Floor | Seq warm | Par warm | Seq cold | Par cold |
|---|---|---|---|---|---|
| Hurl | 0.25 | 1.82 | 1.61 | 2.81 | 2.39 |
| Karate | 0.27 | 5.15 | 4.77 | 7.33 | 6.54 |
| pytest | 0.87 | 2.94 | 3.22 | 4.22 | 4.45 |
| Playwright | 1.09 | 6.08 | 4.92 | 7.96 | 6.98 |
| Tavern | 0.42 | 8.83 | 5.40 | 10.46 | 6.33 |

Warm, parallel against sequential: Tavern saves 39%, Playwright 19%, Hurl 12% and Karate 7%. pytest is 10% slower with `-n 4`: on a suite of about 3 s, starting the workers costs more than parallelism saves. All 200 timed suite runs exited 0.

The largest standard deviations are Playwright cold (0.74 and 0.82 s) and Tavern par warm (0.60 s). Every other cell is at most 0.43 s.

An outage interrupted the run. At 21:36 a cold restart failed because Aidbox could not resolve `fs.get-ig.org` for a package download, and the bench waited on it until 23:27. No timed run was affected, since restarts are not timed. The unfinished cell, Tavern par cold, was discarded and re-measured from scratch after the outage. `restart_aidbox` now retries three times and then stops the bench.

Raw: `runtime.csv`, `runtime/*.json`.

## Time-to-diagnose (`diagnose_prep.sh`)

Mutants 05, 09, 10, 11, 13 × 5 suites = 25 trials, shuffled under neutral names, using the v1 prompt (`diagnose/prompt.txt`). Every suite killed all five, so all 25 ran. Each fresh agent (Opus 5.5) got only its own first mutant-run log. The transcripts confirm each read only that file and used no other tool besides handing back its answer.

The agent launcher allows 20 concurrent agents, so trials 21–25 started after others had finished. The trials are independent, so this does not affect them.

Graded against the mutant diffs on the v1 axes. **Policy**: `id` or `area`. **Change**: `right`, `partly` or `wrong`. The grades are the author's reading and await the user's spot-check.

| Suite | Trials | Policy by id | Change right | Change partly | Reads per trial | Turns per trial |
|---|---|---|---|---|---|---|
| Hurl | 5 | 5 | 5 | 0 | 2.4 | 2.6 |
| Karate | 5 | 5 | 4 | 1 | 2.2 | 3.0 |
| pytest | 5 | 5 | 4 | 1 | 1.0 | 2.0 |
| Playwright | 5 | 5 | 4 | 1 | 1.0 | 2.0 |
| Tavern | 5 | 5 | 3 | 2 | 1.2 | 2.2 |

Per trial (policy / change):

| Mutant | Hurl | Karate | pytest | Playwright | Tavern |
|---|---|---|---|---|---|
| 05 revoked-consent-counts | id / right | id / right | id / right | id / right | id / partly |
| 09 silent-sql-deny | id / right | id / partly | id / partly | id / partly | id / partly |
| 10 single-braces-masked | id / right | id / right | id / right | id / right | id / right |
| 11 scope-drift | id / right | id / right | id / right | id / right | id / right |
| 13 patch-bypass | id / right | id / right | id / right | id / right | id / right |

No answer was wrong. Hurl is the only suite that got mutant 09 fully right, because its long error format prints the policy's SQL. The other suites show that the grant was lost, but not the query. Hurl pays for that detail in read volume: its logs have very long lines and its agents needed the most reads.

In v2, unlike v1, every suite detected every one of these mutants, so the rows are comparable across all five.

Raw: `diagnose/trials.csv` (trial → mutant and suite), `diagnose/answers/`, `diagnose/grades.csv`, `diagnose/audit.csv`, `diagnose/<mutant>/<suite>.log`.
