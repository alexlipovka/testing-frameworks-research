# Desk screening scorecard

Date: 2026-11-07 · Spec: Phase 1 of `.scratch/framework-bakeoff/spec.md`

## Result

| Rank | Tool | Desk score | Status |
|---|---|---|---|
| 1 | Karate 2.1.4 | 85.9% | finalist (fixed) |
| 2 | Hurl | 80.0% | finalist (fixed) |
| 2 | pytest + httpx | 80.0% | finalist (fixed) |
| 4 | **Playwright API testing** | **75.3%** | **joins as 4th finalist** |
| 5 | **Tavern** | **72.9%** | **joins as 5th finalist** (user decision) |
| 6 | REST Assured | 62.4% | out |
| 7 | httpyac | 61.2% | out |
| 8 | Bruno | 58.8% | out |
| 8 | Venom | 58.8% | out |
| 10 | Step CI | 51.8% | out |
| 11 | Newman | 44.7% | out |

**Within-10% rule.** Hurl and pytest tie for 3rd at 80.0%, so the baseline is 80.0% either way. Read as relative, a candidate qualifies at 0.9 × 80.0% = 72.0% or above. An absolute reading (70.0% or above) admits the same two tools. The spec allows one 4th finalist, which goes to the higher-scoring Playwright. Tavern also clears the threshold, and the user added it as a 5th finalist (2026-11-07), above the spec's 4-finalist budget.

**The margins are thin.** Playwright clears 72.0% by 3.3 percentage points and Tavern by 0.9. A one-step drop on a weight-10 criterion is −2.35 pp, and on a weight-5 criterion it is −1.18 pp. So a single Eco or FHIR step would push Tavern out, and a single step on any weight-10 criterion would leave Playwright with only 1 pp to spare. Re-scoring Hurl or pytest would also move the threshold.

## Method

- These scores come from docs and repo data only. The bake-off measurements in the spec replace them in Phase 2.
- **AI-agent authorability (weight 15) is excluded.** It can only be measured by running the experiment. The remaining weights add up to 85, and each score is weighted sum ÷ (85 × 5).
- The three finalists are scored here as well, because the within-10% rule needs a baseline. Karate is scored as the pinned 2.1.4 (re-scored 2026-11-08; the 1.5.x line scored 81.2%: Diag 4, Eco 3).
- Each desk score is a proxy for the bake-off measurement:

| Criterion | Weight | Desk proxy |
|---|---|---|
| AP (access policy) expressiveness | 25 | Declarative assertions on the `__debug=policy` / `eval-result` dump; array filters; a 5×4 matrix without copy-paste |
| Failure diagnostics | 15 | What a failure prints: request/response, an actual-vs-expected diff, the source line |
| Runtime & parallelism | 10 | Startup cost (native binary < Python/Node < JVM+build) together with built-in parallel runs |
| Readability | 10 | How close the test reads to the HTTP exchange itself |
| Fixtures / isolation | 10 | Setup/teardown hooks, captures, run-scoped variables such as `run_id` |
| CI & reports | 5 | JUnit, HTML, exit codes, all built in |
| Ecosystem health | 5 | Releases, contributor spread and license (tables below) |
| FHIR awareness | 5 | 3 = a mainstream FHIR library (fhir.resources/fhirpathpy, HAPI, fhirpath.js) works natively in the test language; 2 = only through an escape hatch (external functions, Java interop); 1 = none |

## Scores (1–5)

Column key: AP = access-policy expressiveness, Diag = failure diagnostics, Run = runtime & parallelism, Read = readability, Fix = fixtures / isolation, CI = CI & reports, Eco = ecosystem health, FHIR = FHIR awareness. Σ is the weighted sum out of 425.

| Tool | AP | Diag | Run | Read | Fix | CI | Eco | FHIR | Σ | % |
|---|---|---|---|---|---|---|---|---|---|---|
| Karate 2.1.4 | 5 | 5 | 3 | 4 | 4 | 5 | 4 | 2 | 365 | 85.9 |
| Hurl | 4 | 4 | 5 | 5 | 3 | 5 | 4 | 1 | 340 | 80.0 |
| pytest + httpx | 4 | 4 | 4 | 3 | 5 | 4 | 5 | 3 | 340 | 80.0 |
| Playwright API | 3 | 4 | 4 | 3 | 5 | 5 | 5 | 3 | 320 | 75.3 |
| Tavern | 4 | 3 | 4 | 4 | 4 | 4 | 3 | 2 | 310 | 72.9 |
| REST Assured | 3 | 4 | 2 | 2 | 4 | 4 | 3 | 3 | 265 | 62.4 |
| httpyac | 3 | 3 | 3 | 5 | 3 | 4 | 1 | 1 | 260 | 61.2 |
| Bruno | 2 | 3 | 3 | 4 | 3 | 5 | 5 | 1 | 250 | 58.8 |
| Venom | 3 | 3 | 3 | 3 | 3 | 4 | 3 | 1 | 250 | 58.8 |
| Step CI | 3 | 2 | 3 | 4 | 2 | 3 | 1 | 1 | 220 | 51.8 |
| Newman | 2 | 3 | 2 | 2 | 2 | 4 | 2 | 1 | 190 | 44.7 |

Weights: AP 25 · Diag 15 · Run 10 · Read 10 · Fix 10 · CI 5 · Eco 5 · FHIR 5.

### Rationale

- **Karate 2.1.4.**
  - `match` handles fuzzy and partial JSON.
  - Scenario Outline `Examples:` tables give the matrix with no copy-paste.
  - v2 is a ground-up rewrite (2.0.0, 2026-03-26). Soft assertions collect every JSON mismatch instead of stopping at the first. The interactive HTML report shows the request and response for each step. Diag is 5.
  - A custom JS engine (`karate-js`) replaces GraalJS, and parallel runs use Java 21 virtual threads. Run stays 3: a cold JVM start remains, and the bake-off measures it.
  - It ships as a standalone jar and a CLI, so no Maven or Gradle is needed.
  - Eco is 4: 17 v2 releases in 12 months, MIT. But one author wrote 1660 of the 1800 commits.
- **Hurl.**
  - JSONPath filter assertions sit next to the request in plain text, the best fit for `eval-result`.
  - There is no loop or parameterization, so the matrix needs one file per row or an external loop.
  - It is a native Rust binary with `--parallel` and JUnit, HTML and TAP output.
  - Setup and teardown are just more files with captures; there are no hooks.
- **pytest + httpx.**
  - `parametrize` builds the matrix, and fixture scopes are best-in-class.
  - Assertions are hand-written Python over JSON, so cases are wordier than Hurl's.
  - Assertion rewriting gives diffs, but request/response dumps only appear if the suite adds them.
  - JUnit output is built in; HTML needs the `pytest-html` plugin.
- **Playwright API testing.**
  - Tests use the `request` fixture with TS `expect` and `toMatchObject`, and a plain loop builds the matrix.
  - Filtering the debug dump takes JS, so it loses ground on AP and readability.
  - Its strengths are worker-scoped fixtures, the HTML and JUnit reporters, API calls captured in the trace viewer, and fhirpath.js working natively.
- **Tavern.**
  - Tests are YAML on top of pytest. `marks: parametrize` gives the matrix and `finally` stages handle teardown. It inherits pytest fixtures, xdist and JUnit.
  - Checking an array inside `eval-result` needs `validate_content` or `check_jmespath_match` external functions, which is verbose.
  - Eco is 3: 6 authors in 12 months, but one wrote half the commits. 4.0 is at rc2.
  - It overlaps heavily with the pytest finalist.
- **REST Assured.**
  - GPath `findAll{}` filters and JUnit 5 `@ParameterizedTest` work, and `log().ifValidationFails()` dumps the full exchange.
  - HAPI FHIR is native in Java.
  - Java ceremony and a compile step cost it on readability and runtime.
  - One author wrote 199 of the 250 commits in the last 12 months.
- **httpyac.**
  - `.http` files with `??` assertions and `@loop` read as close to the HTTP exchange as Hurl does, and `--junit` exists.
  - It is near-dormant: the last release was 6.16.7 (2025-03-30), with 3 commits in the last 12 months.
- **Bruno.**
  - Declarative `assert` lines cover simple checks, but array filters need JS.
  - The `bru run` source at v4.3.0 has no data-file or iteration flag, so the matrix means copy-paste.
  - JUnit, HTML and JSON reporters are built in.
  - It has the strongest community of the desk candidates.
- **Venom.**
  - YAML executors with `ShouldXxx` assertions and `range:` loops, plus XML and HTML reports.
  - It is a native Go binary that starts fast, but its README documents no parallel runs. Run is 3 because sequential execution cancels out the startup advantage.
  - The latest stable release is v1.3.0 (2026-01-06); only betas since then.
- **Step CI.**
  - YAML with JSONPath checks.
  - The last commit was 2024-08 and the last release 2.8.2 was 2024-06-10. It is effectively abandoned.
- **Newman.**
  - Postman collection JSON with `pm.test` JS assertions and CSV/JSON iteration data, which allows one dataset per run.
  - It has no parallel mode, and HTML needs an external reporter.
  - Postman is steering users to Postman CLI.

## Ecosystem data (fetched 2026-11-07)

"12m" means since 2025-11-07. Commit and author counts come from the full paginated commit history on the default branch, with bots excluded.

| Tool | Repo | License | ★ | Latest | Releases 12m | Commits / authors 12m |
|---|---|---|---|---|---|---|
| [Hurl](https://hurl.dev) | [Orange-OpenSource/hurl](https://github.com/Orange-OpenSource/hurl) | Apache-2.0 | 19.3k | 8.1.0 (2026-10-28) | 4 | 814 / 14 |
| [Karate](https://karatelabs.io) | [karatelabs/karate](https://github.com/karatelabs/karate) | MIT | 9.0k | 1.x: 1.5.2 (2025-11-30); v2.1.4 (2026-10-22) | 18 (1 on 1.x) | 1800 / 11 |
| [pytest](https://docs.pytest.org) + [httpx](https://www.python-httpx.org) | [pytest-dev/pytest](https://github.com/pytest-dev/pytest) | MIT | 14.7k | 9.2.0 (2026-10-27) | 7 | 931 / 124 |
| [Tavern](https://taverntesting.github.io) | [taverntesting/tavern](https://github.com/taverntesting/tavern) | MIT | 1.2k | 3.7.2 (2026-10-28), 4.0.0rc2 | 22 (PyPI) | 119 / 6 |
| [Bruno](https://www.usebruno.com) | [usebruno/bruno](https://github.com/usebruno/bruno) | MIT | 48.3k | v4.3.0 (2026-10-22) | 28 (30 CLI) | 1692 / 130 |
| [httpyac](https://httpyac.github.io) | [AnWeber/httpyac](https://github.com/AnWeber/httpyac) | MIT | 0.9k | 6.16.7 (2025-03-30) | 0 | 3 / 3 |
| [Newman](https://learning.postman.com/docs/collections/using-newman-cli/command-line-integration-with-newman/) | [postmanlabs/newman](https://github.com/postmanlabs/newman) | Apache-2.0 | 7.3k | 6.2.3 (2026-10-09) | 2 (npm) | 11 / 5 |
| [Step CI](https://stepci.com) | [stepci/stepci](https://github.com/stepci/stepci) | MPL-2.0 | 1.9k | 2.8.2 (2024-06-10) | 0 | 0 / 0 |
| [Venom](https://github.com/ovh/venom) | [ovh/venom](https://github.com/ovh/venom) | Apache-2.0 | 1.2k | v1.4.0-beta.4 (2026-10-01); stable v1.3.0 | 4 | 28 / 10 |
| [REST Assured](https://rest-assured.io) | [rest-assured/rest-assured](https://github.com/rest-assured/rest-assured) | Apache-2.0 | 7.1k | 6.3.0 (2026-10-23) | 4 (Maven) | 250 / 12 |
| [Playwright](https://playwright.dev/docs/api-testing) | [microsoft/playwright](https://github.com/microsoft/playwright) | Apache-2.0 | 99.5k | v1.65.0 (2026-11-05) | 15 | 2834 / 174 |

## Noted, not scored

These solve different problems and are out of scope.

- **[Schemathesis](https://schemathesis.readthedocs.io)** ([repo](https://github.com/schemathesis/schemathesis); MIT, v4.33.1, 2026-11-04; very active). Property-based fuzzing from an OpenAPI schema. It cannot check per-identity authorization decisions.
- **[Inferno](https://inferno-framework.github.io)** ([inferno-core](https://github.com/inferno-framework/inferno-core); Apache-2.0, v1.6.0, 2026-10-27). Checks FHIR server conformance against Implementation Guides.
- **[k6](https://grafana.com/docs/k6/latest/)** ([repo](https://github.com/grafana/k6); AGPL-3.0, v1.8.2, 2026-10-12). Load testing with JS `check()` assertions.

Pins (decision 2026-11-08): Hurl 8.1.0 and Karate 2.1.4. The existing production suite still runs Hurl 8.0.1; `REPORT.md` must note it.

## Open questions for the user

1. **Excluding authorability.** Leaving AI-agent authorability out of the desk score is my call, not the spec's. If it were included as a guess, it would decide the cut.
