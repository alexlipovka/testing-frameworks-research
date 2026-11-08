# Testing framework bake-off: report

## Result

**Recommendation: pytest + httpx as the single tool for new API-level and access-policy tests. Keep the existing production suite running, and don't migrate it on this evidence.** Section 4 gives the reasoning and what would change it.

| Rank | Suite | Score (of 100) |
|---|---|---|
| 1 | pytest + httpx | 84.5 |
| 2 | Playwright API | 80.0 |
| 3 | Karate | 71.0 |
| 4 | Hurl | 60.5 |
| 5 | Tavern | 51.5 |

pytest stays first in 16 of the 18 weight and scoring variations tried, and Playwright takes first in the other two. The top two are clear; the gap between them is small (4.5 points, less than one access-policy step). The readability scores are the author's and await the user's review. The time-to-diagnose grades await the user's spot-check.

## 1. How measurements become scores

These rules were written down before any score was computed. They are not blind: the raw measurements already existed when the bands were chosen, so read the bands as stated judgement and use the sensitivity check to see how much they matter.

Every criterion is scored 1–5. Where a criterion averages two measurements, half-steps are kept rather than rounded away. Ranking is the weighted sum (spec weights, out of 500). The tie-break is mutant kill rate.

"Ratio" below means the suite's value divided by the best suite's value, so those bands are relative to this field of five.

| Criterion | Weight | Measured value | Mapping to 1–5 |
|---|---|---|---|
| AP expressiveness | 25 | LOC per AP case: (AP cases 1–9 + 9/15 of shared code) ÷ 9. Shared helpers, fixtures and runners count, because they are code someone maintains. | Ratio ≤1.15 → 5, ≤1.40 → 4, ≤1.70 → 3, ≤2.00 → 2, above → 1. Then −1 (floor 1) if case 8 lacks either native parameterization or a decision assertion in every cell, which spec case 8 requires. |
| Failure diagnostics | 15 | Average of two parts. **Kill**: mutants killed of 15. **Diagnose**: (cause right + ½ cause partly right) ÷ trials run. | Kill: 14–15 → 5, 13 → 4, 12 → 3, 10–11 → 2, below → 1. Diagnose: ≥0.95 → 5, ≥0.80 → 4, ≥0.60 → 3, ≥0.40 → 2, below → 1. |
| Runtime & parallelism | 10 | Mean warm seconds in the suite's best available mode (native parallel if it has one). | Ratio ≤1.30 → 5, ≤2.00 → 4, ≤3.00 → 3, ≤4.00 → 2, above → 1. Then −1 (floor 1) if there is no safe parallelism out of the box, which the spec makes a scored finding. |
| AI-agent authorability | 15 | Average of two parts, cases 3–15. **First run**: cases passing of 13. **Fixes**: total fix iterations. | First run: ≥12 → 5, 10–11 → 4, 7–9 → 3, 4–6 → 2, 0–3 → 1. Fixes: ≤2 → 5, ≤4 → 4, ≤6 → 3, ≤10 → 2, above → 1. |
| Readability | 10 | The rubric below, applied to cases 2 and 8. Scored by the author. **Awaiting the user's review.** | Mean of the four rubric items, to the nearest half. |
| Fixtures / isolation | 10 | Four checks from the bake-off. | 1 + number of checks passed. |
| CI & reports | 5 | JUnit, HTML, exit codes. | All three built in → 5. One through a plugin → 4. One missing → 3. Two missing → 2. Three missing → 1. |
| Ecosystem health | 5 | Desk score from `research/scorecard.md`. | Carried over unchanged. |
| FHIR awareness | 5 | Desk score from `research/scorecard.md`, changed only if the bake-off contradicts it. | 3 = a mainstream FHIR library works natively in the test language. 2 = only through an escape hatch. 1 = none. |

**Fixtures / isolation checks.**

- **A. Native lifecycle.** The framework itself runs both run-scoped setup and teardown, with no shell wrapper.
- **B. Teardown after a failed test.** Teardown still runs when tests fail.
- **C. Recovery from a killed run, verified.** A killed run was shown to be rolled back. A mechanism that exists but was never exercised does not count.
- **D. Parallel-ready fixtures.** The framework's native parallel mode shares one run-scoped fixture across workers without extra code. This is a framework property. A data collision inside one suite's tests is reported separately and not charged here.

**Readability rubric** (each item 1–5, judged on cases 2 and 8).

- **R1 Locality.** Identity, request and expected decision are visible together in the case.
- **R2 Indirection.** How little helper code you must read to know what the case asserts. 5 = none.
- **R3 Signal.** How much of the case is about the domain rather than framework ceremony.
- **R4 Matrix.** Whether case 8 reads as a table of identities, operations and decisions.

## 2. Scores, and why each is what it is

| Criterion | Weight | Hurl | Karate | pytest | Playwright | Tavern |
|---|---|---|---|---|---|---|
| AP expressiveness | 25 | 2 | 4 | 5 | 3 | 2 |
| Failure diagnostics | 15 | 4 | 4 | 4 | 4 | 3.5 |
| Runtime & parallelism | 10 | 5 | 4 | 4 | 4 | 1 |
| AI-agent authorability | 15 | 1.5 | 2 | 4.5 | 5 | 2 |
| Readability (awaiting review) | 10 | 4 | 4 | 4 | 3.5 | 3 |
| Fixtures / isolation | 10 | 3 | 3 | 3 | 5 | 4 |
| CI & reports | 5 | 5 | 5 | 4 | 5 | 4 |
| Ecosystem health | 5 | 4 | 4 | 5 | 5 | 3 |
| FHIR awareness | 5 | 1 | 2 | 3 | 3 | 2 |
| **Weighted sum (of 500)** | | **302.5** | **355** | **422.5** | **400** | **257.5** |
| **Score (of 100)** | | **60.5** | **71.0** | **84.5** | **80.0** | **51.5** |

No two suites tie, so the tie-break was not used.

**AP expressiveness.** pytest is the shortest even with its helpers counted. Hurl has the least shared code but repeats request bodies inline, and it takes the only matrix penalty.

| | Hurl | Karate | pytest | Playwright | Tavern |
|---|---|---|---|---|---|
| AP cases 1–9 (LOC) | 378 | 292 | 185 | 315 | 421 |
| Shared code (LOC) | 21 | 116 | 142 | 214 | 121 |
| LOC per AP case, shared included | 43.4 | 40.2 | 30.0 | 49.3 | 54.8 |
| Ratio to best | 1.45 | 1.34 | 1.00 | 1.64 | 1.83 |
| Band | 3 | 4 | 5 | 3 | 2 |
| Case 8 | shell loop, status only: −1 | table, decision per cell | table, decision per cell | loop over a table, decision per cell | table, decision per cell |
| **Score** | **2** | **4** | **5** | **3** | **2** |

**Failure diagnostics.** The two parts pull in opposite directions, so four suites land on 4 for different reasons. Hurl catches the most and explains the least. Karate and Playwright explain well but caught the fewest, and their diagnosis results exclude mutant 09.

| | Hurl | Karate | pytest | Playwright | Tavern |
|---|---|---|---|---|---|
| Mutants killed of 15 | 14 | 12 | 13 | 12 | 13 |
| Kill band | 5 | 3 | 4 | 3 | 4 |
| Trials run | 5 | 4 | 5 | 4 | 5 |
| Named the policy by id | 1 | 4 | 4 | 4 | 4 |
| Cause right / partly | 2 / 3 | 4 / 0 | 4 / 1 | 4 / 0 | 2 / 3 |
| Diagnose value | 0.70 | 1.00 | 0.90 | 1.00 | 0.70 |
| Diagnose band | 3 | 5 | 4 | 5 | 3 |
| **Score** | **4** | **4** | **4** | **4** | **3.5** |

**Runtime & parallelism.**

| | Hurl | Karate | pytest | Playwright | Tavern |
|---|---|---|---|---|---|
| Best-mode warm mean (s) | 2.45 (par) | 4.85 (par) | 3.05 (seq) | 4.81 (par) | 8.52 (seq) |
| Ratio to best | 1.00 | 1.98 | 1.24 | 1.96 | 3.48 |
| Band | 5 | 4 | 5 | 4 | 2 |
| Safe parallelism out of the box | yes | yes | no: −1 | yes | no: −1 |
| **Score** | **5** | **4** | **4** | **4** | **1** |

**AI-agent authorability.**

| | Hurl | Karate | pytest | Playwright | Tavern |
|---|---|---|---|---|---|
| First run, cases passed of 13 | 6 | 5 | 11 | 12 | 0 (9 after one shared fix) |
| First-run band | 2 | 2 | 4 | 5 | 1 |
| Fix iterations | 11 | 9 | 2 | 1 | 5 |
| Fix band | 1 | 2 | 5 | 5 | 3 |
| **Score** | **1.5** | **2** | **4.5** | **5** | **2** |

Most fixes were wrong guesses about the SUT rather than framework errors: `$extract` parameter names, `gender: robot` being accepted, absolute `location` URLs. The framework-caused failures were Karate's `[var]` array-literal rule (5 of its 8 failing cases), Tavern's collection-time formatting (6 of 13 cases hit it) and one Tavern JMESPath helper. Hurl had one syntax slip.

**Readability** (author's scoring, awaiting the user's review).

| | Hurl | Karate | pytest | Playwright | Tavern |
|---|---|---|---|---|---|
| R1 Locality | 5 | 5 | 4 | 4 | 3 |
| R2 Indirection | 5 | 3 | 3 | 3 | 3 |
| R3 Signal | 3 | 3 | 4 | 3 | 2 |
| R4 Matrix | 3 | 5 | 5 | 3 | 4 |
| Mean | 4.0 | 4.0 | 4.0 | 3.25 | 3.0 |
| **Score** (half-up) | **4** | **4** | **4** | **3.5** | **3** |

Hurl needs no helper knowledge, but each decision is two requests written out, and its matrix is split across a table, a template and a shell loop. Karate's case 2 is one table, while its case 8 embeds a JavaScript function. pytest reads as one line per check, but `expect_allow` hides the two-request protocol. Playwright carries async and typing ceremony around the same helpers. Tavern repeats two stages and an `$ext` header in every case.

**Fixtures / isolation.**

| Check | Hurl | Karate | pytest | Playwright | Tavern |
|---|---|---|---|---|---|
| A. Native lifecycle | no (shell) | no (no after-suite hook) | yes | yes | yes |
| B. Teardown after a failed test | yes | yes | yes | yes | yes |
| C. Killed-run recovery verified | no | no | no | yes | yes |
| D. Parallel-ready fixtures | yes | yes | no (one run per xdist worker) | yes | no |
| **Score** | **3** | **3** | **3** | **5** | **4** |

Check C is a property of what each suite built, not of the framework. pytest keeps its transaction stamp only in memory, while Tavern, on the same engine, persists it. Karate's `run.sh teardown` exists but was never exercised against a killed run, so it does not count.

**CI & reports.** All five have JUnit and exit codes. HTML is built in for Hurl, Karate and Playwright and needs a plugin for pytest and Tavern. Scores: 5, 5, 4, 5, 4.

**Ecosystem health and FHIR awareness.** Carried over from `research/scorecard.md`. No suite used a FHIR library (checked by search), so the bake-off gave no reason to change the FHIR scores.

## 3. Sensitivity

Each row changes one thing. "Others scaled" keeps the remaining weights in proportion and summing to 100.

| Change | 1st | 2nd | 3rd | 4th | 5th |
|---|---|---|---|---|---|
| **Base** | pytest 84.5 | Playwright 80.0 | Karate 71.0 | Hurl 60.5 | Tavern 51.5 |
| AP weight 40 | pytest 87.6 | Playwright 76.0 | Karate 72.8 | Hurl 56.4 | Tavern 49.2 |
| Diagnostics weight 30 | pytest 83.7 | Playwright 80.0 | Karate 72.6 | Hurl 63.9 | Tavern 54.8 |
| Runtime weight 25 | pytest 83.8 | Playwright 80.0 | Karate 72.5 | Hurl 67.1 | Tavern 46.2 |
| Runtime weight 0 | pytest 85.0 | Playwright 80.0 | Karate 70.0 | Hurl 56.1 | Tavern 55.0 |
| Authorability weight 30 | pytest 85.5 | Playwright 83.5 | Karate 65.5 | Hurl 55.1 | Tavern 49.5 |
| Authorability weight 0 | pytest 83.5 | Karate 76.5 | Playwright 76.5 | Hurl 65.9 | Tavern 53.5 |
| Readability weight 25 | pytest 83.8 | Playwright 78.3 | Karate 72.5 | Hurl 63.8 | Tavern 52.9 |
| **Fixtures weight 25** | **Playwright 83.3** | pytest 80.4 | Karate 69.2 | Hurl 60.4 | Tavern 56.2 |
| **Equal weights** | **Playwright 83.3** | pytest 81.1 | Karate 71.1 | Hurl 65.6 | Tavern 54.4 |
| AP LOC without shared code | pytest 84.5 | Playwright 80.0 | Karate 66.0 | Hurl 55.5 | Tavern 46.5 |
| No Hurl matrix penalty | pytest 84.5 | Playwright 80.0 | Karate 71.0 | Hurl 65.5 | Tavern 51.5 |
| Undetected 09 counts as a failed diagnosis | pytest 84.5 | Playwright 78.5 | Karate 69.5 | Hurl 60.5 | Tavern 51.5 |
| Diagnostics from diagnosis only, no kill rate | pytest 84.5 | Playwright 83.0 | Karate 74.0 | Hurl 57.5 | Tavern 50.0 |
| Tavern first run counted as 9/13 | pytest 84.5 | Playwright 80.0 | Karate 71.0 | Hurl 60.5 | Tavern 54.5 |
| pytest and Playwright first run −3 (familiarity) | pytest 83.0 | Playwright 77.0 | Karate 71.0 | Hurl 60.5 | Tavern 51.5 |
| Readability equal for all five | pytest 84.5 | Playwright 81.0 | Karate 71.0 | Hurl 60.5 | Tavern 53.5 |
| Hurl readability 5 | pytest 84.5 | Playwright 80.0 | Karate 71.0 | Hurl 62.5 | Tavern 51.5 |
| pytest gets killed-run recovery | pytest 86.5 | Playwright 80.0 | Karate 71.0 | Hurl 60.5 | Tavern 51.5 |

With Authorability at 0, Karate and Playwright tie at 76.5 and also tie on kill rate (12), so the spec's tie-break does not separate them.

**Random weights.** Multiplying each weight by a random factor from 0.5 to 1.5 and renormalising, 20,000 draws: pytest is first in 91.7% and Playwright in 8.3%. Those two fill the top two places in every draw.

**What actually moves first place.** One step on a criterion is worth (weight ÷ 5) points. The lead is 4.5, so a single AP step (5 points) is enough: pytest at 4, or Playwright at 4, puts Playwright first. Authorability would need 1.5 steps. Readability would need a combined swing of 2.5 steps between the two. pytest's AP 5 is partly structural, because the ratio bands give the shortest suite the top score. Hurl does not reach first in any variation, and no AP weight changes that even with the matrix penalty removed.

## 4. Recommendation

**Use pytest + httpx as the single tool for new API-level and access-policy tests.**

- It was the shortest suite with its helpers counted. Its 5×4 matrix is a plain-text table.
- An agent wrote 11 of 13 cases correctly on the first run. Both failures were wrong guesses about Aidbox.
- `expect_allow` and `expect_deny` put the decision, the crash check and the status behind one line. Its failure output named the policy by id in 4 of 5 diagnosis trials.
- It is the same language as aidbox-python-sdk apps, though this bake-off used raw httpx and did not exercise the SDK client. These numbers give no reason to adopt the spec's example split of "Hurl for policies + pytest for SDK flows" for new work.

**Keep the existing production suite running, and don't migrate it on this evidence.** Migrating it was not measured here. Hurl had the fastest runs and the simplest case files, and it killed the most mutants. Its weaknesses here are the status-only matrix and failure output that rarely names a policy. Decision assertions should address the second one, since the one Hurl trial that named a policy did so through a failing decision assertion.

**Build into the pytest setup before relying on it:** persist the transaction stamp so a killed run can be rolled back, which Tavern showed works on the same engine. Parallel runs would need the run opened outside xdist workers.

**What would change this recommendation.**

- **To Playwright:** the team is TypeScript-first, or fixtures and crash safety matter more than expressiveness. Equal weights or a Fixtures weight of 25 already put it first. Repeat authoring runs that close the AP or authorability gap would too.
- **To keeping Hurl for access policies:** a costed migration showing the move is not worth it, or a team that values no-helper test files above the matrix and diagnostics gaps. This is a cost argument the scores don't capture.
- **To Karate:** nothing tested here. It needs its authoring cost to fall and is third throughout, or tied second with Authorability removed.
- **Against pytest:** a repeat of the authoring run (N = 1) with results well below 11 of 13, or the user's readability review moving pytest down and Playwright up by a combined 2.5 steps.
- **At larger scale:** a real measurement at the existing production suite's size, if runner overhead turns out to dominate there. See the runtime limit below.

## 5. Findings credited to each framework

34 findings, in full in `research/findings.md`. They are credited to the suite whose writing surfaced them. The revision pass that feeds them back comes after this report.

| Suite | Findings | Mix | What it surfaced |
|---|---|---|---|
| Hurl | 2 | SUT 1, framework 1 | Allowed `$extract` can only assert the policy gate, because the SUT lacks fhir-emr's launch context (this amended spec case 9). No native parameterization, so the matrix is a status-only shell loop. |
| Karate | 5 | SUT 1, Aidbox 1, spec gap 1, framework 2 | `$extract`'s `questionnaire_response` parameter name. Aidbox accepts `gender: 'robot'`. Mutants 07 and 08 survive a literal reading of case 1, the most consequential spec gap found. `[var]` in `match` is a literal. No after-suite hook. |
| pytest | 8 | Aidbox 4, spec gap 2, framework 2 | The debug dump answers 200 with the decision only in `eval-result`, and SQL denies can be `null`. User-reference policy links don't apply to password sessions. A throwing SQL policy looks like a plain 403, so only the dump tells them apart. Absolute transaction `location`. Spec gaps on case 3 policies and case 15. xdist runs a session fixture per worker. httpx `json=` forces the content type. |
| Playwright | 10 | Aidbox 3, SUT 1, spec gap 1, framework 5 | `__debug` does not execute the request, so each check is two calls. `null` is shared by no-row and crashed. A malformed `$populate` body makes a baseline SDC policy throw, a way to test case 3 without changing policies. Absolute `location`. Case 15 cannot live inside one run. Framework notes on globalSetup teardown, runner crashes leaving rows, CLI reporters replacing config, disposed response bodies, and building the matrix with a plain loop. |
| Tavern | 9 | Aidbox 4, spec gap 1, framework 4 | `parametrize` formats at collection, so one bad file aborts the session. The built-in JMESPath helper receives a Response, not JSON. No nested formatting. Python as PID 1 ignores SIGTERM. `eval-result` null on no match. A run-scoped throwing policy as a positive control for case 3. Validation severity is `fatal`. Absolute `location`. `family=Bakeoff` is a prefix match, so it collides with run-prefixed families. |

Several findings were reached independently: the `null` deny (pytest, Playwright, Tavern, and a Hurl fix iteration) and the absolute `location` URL (pytest, Playwright, Tavern). Hurl also found a silent-pass trap while authoring: with the wrong `$extract` parameter name, the deny cases passed for the wrong reason and only the allow side exposed it. That is the practical argument for allow and deny in every case.

## 6. Limits

**Kill rate.**

- The 12–14 of 15 differences come from which rows each agent happened to write (mutants 07, 08, 09), not from framework capability. No suite killed 07, which is a spec gap: no case requires a request with an Encounter id under another type.
- Only 1 of 15 kills is decision-only (mutant 10). But ticket 04 built and verified the mutants by their probes flipping a verdict, so the set under-represents decision-only bugs. Don't read this as "status codes are enough". The diagnostic value of decision assertions is a separate matter: it is what named the policy in the time-to-diagnose trials.
- Every authoring run was told to read `sut/mutants/README.md`, which lists each mutant and its probe. Absolute kill rates are therefore optimistic.
- Karate: ticket 06's sanity sweep reported 13/15 untuned, and ticket 08 measured 12/15 (09 also survives). Case 14's flake may explain the earlier number, but that is unconfirmed. This report uses 12/15.

**Karate parallel runs.** Case 14 flakes under 4 threads because other features create `Bakeoff` Patients that its search can see. That is a data collision in this suite, not a defect in Karate. Karate's parallel warm runs failed 3 of 10 times. hyperfine kept no output for those runs, so the collision is unconfirmed as the cause.

**Authorability.** There was one authoring run per framework (N = 1), so a small part of any gap may be chance.

- Tavern is scored 0/13, noted as 9/13 after one shared fix.
- Python and TypeScript familiarity likely favours pytest and Playwright.
- pytest's run saw the truncated start (about 100 characters each) of the then-existing findings rows.
- Extra reads and probes differed per suite, from the ticket comments:

| Suite | Read beyond the listed files, or probed |
|---|---|
| Hurl | Reuses `sut/fixtures/run.sh` for setup. The ticket records no other reads or probes. |
| Karate | `sut/fixtures/fixtures.json` and `run.sh`. One live request to learn the debug shape. The SDC policy's debug trace during the case 9 fix. |
| pytest | `fixtures.json`, `run.sh`, `compose.yaml`, `smoke.sh`. Curl probes of the debug dump before the examples. |
| Playwright | `fixtures.json`, `run.sh`, `sut/mutants/revert.sh`. Hand probes of the debug dump and of a `$populate` body that case 3 relies on. |
| Tavern | `fixtures.json`, `run.sh`, `compose.yaml`, Tavern's installed source. About 9 curl requests in one probe run. |

**Runtime.** The suites span about 2.5–8.5 s for 15 cases on one four-core machine. That supports an ordering at this size and shows startup is small (floors of 0.23–1.10 s). It does not predict the existing production suite: Hurl ran about 80 requests here against far more there, no runtime for that suite is on record, and per-request overhead was not isolated. The small parallel gains (5–24%) suggest fixed setup and teardown dominate at this size, so parallelism could matter more at larger scale, but that is an inference. Tavern took 8.5 s for 93 tests against pytest's 3.05 s for 65, which hints at per-test cost, but the suites differ in what they do.

**Time-to-diagnose.** Grades are the author's and await the user's spot-check. 23 of 25 trials ran. Karate's and Playwright's results exclude mutant 09, the hardest of the five, because they never detected it. The agents were one model reading logs, not engineers.

**Hurl.** It runs 8.1.0 here and the existing production suite runs 8.0.1. Its case 8 asserts status only.

**Selection.** Tavern and Playwright joined by user decision, beyond the one extra slot of the within-10% rule. Desk scores and these scores use different bases, so they are not comparable.

**Scoring.** The bands were chosen with the raw data already known, and readability is one author's judgement. Ecosystem and FHIR scores are desk scores from 2026-11-07.

## 7. Raw numbers

Every number the scores use appears in section 2. Full data: `bench/results/results.md`, `bench/results/loc.csv`, `bench/results/mutant-matrix.csv`, `bench/results/mutants.csv`, `bench/results/runtime.csv`, `bench/results/diagnose/`. Authorability detail is in the comments on tickets 05, 06, 07, 10 and 11, under `.scratch/`, which is not in git.
