# FPML for API testing

Date: 2026-11-08 · Question: should FPML be adopted for API testing in this repo, and in what role? · Hypothesis under test: "it looks kinda similar to Tavern yaml files and also binds well with python."

Every claim carries one label. **[ran]** means verified by running it in the spike. **[src]** means verified from source, with the citation next to it. **[inf]** means inferred.

Citations `extract.py`, `evaluator.py`, `guarded_resource.py` are under `fpml/core/` in fpml 1.0.0's site-packages. `tavern/...` is the installed Tavern 3.7.2 package. `op/` is the `op-fhir-middleware` directory of the project behind the existing production suite. `README:N` is line N of [the upstream README](https://github.com/beda-software/FHIRPathMappingLanguage/blob/main/README.md).

## Result

**Recommendation: do not adopt FPML for API testing here, in any role.** Keep it where it already works, as a mapping engine, and test it as code under test.

1. **The resemblance to Tavern is superficial.** Both are YAML with braces. A Tavern file is an executable test: stages, a request, an expected response, pass or fail [src: `tavern/_plugins/rest/response.py:63-102`]. An FPML template is a pure function from data to data. It has no HTTP, no stages, no assertion and no pass or fail. The public API is `resolve_template` plus the evaluator factory and the error class [src: `fpml/__init__.py:14-20`]. Using FPML as a test format means writing the test runner yourself [inf].
2. **"Binds well with Python" is true, and does not help.** The binding is one function, and op-fhir-middleware uses it cleanly [src: `op/app/fhir/mapping/runner.py:59`]. But the part with testing value is FHIRPath, supplied by `fhirpathpy`. FPML adds templating on top, and that templating is the part that hides errors.
3. **FPML's core semantic is wrong for tests.** An empty slot deletes its key [src: `extract.py:181-182`, `README:238-271`]. In a rendered expected document, a mistyped path deletes the constraint and the check passes [ran]. Its one mitigation, `{{+ +}}`, is marked "not mature enough and might change" [src: `README:276`].
4. **The tool it would plug into is already ranked last.** Tavern scored 51.5 of 100 and the report recommends pytest + httpx [src: `REPORT.md:5-13`]. Inside Tavern, FPML's `{{ }}` is eaten by Tavern's own formatter [ran].
5. **It would not move the benchmark.** Mutants change access policies, and they are detected by status codes and dump fields that every suite can already read [src: `sut/mutants/README.md:3-7`]. Differences in kill rate come from which rows were written [src: `REPORT.md:216`]. A different assertion syntax adds no detection power on its own [inf].

**The only adoption with a case is plain FHIRPath, not FPML:** a small `fhirpathpy` assertion helper in the pytest suite, used where the data is FHIR-shaped. That is optional, needs the measurement in [Evaluation](#evaluation-with-bench) first, and has its own silent-pass cases (below). It would not change the FPML verdict.

**What would change this:** a need to generate structurally complex FHIR bodies from data, where conditionals and iteration beat Python, and an FPML that fails on an empty required slot. Neither exists today [inf].

### Findings that go beyond the question

- **fhirpathpy accepts some syntax errors and silently drops the rest of the expression.** `%r.active) and false` returns `[True]` [ran]. The parser has no effective error listener and parses the `expression` rule, not the EOF-anchored `entireExpression` [src: `fhirpathpy/parser/__init__.py:19-32`, `antlr4/error/ErrorListener.py:15-16`, `FHIRPathParser.py:124`]. This reaches the production mappers too, since they use the same engine [inf]. Worth reporting upstream.
- **A typo in a real production mapper's optional field is invisible at runtime.** op-fhir-middleware's real `Patient.read` with `lname` mistyped returned a valid Patient with no `family` and no error, through `strict=True` and pydantic validation [ran]. Only a field-level test catches it, and one exists for Patient [src: `op/tests/patient/test_mapper.py:56`].
- **Tavern's native `save` has the same class of bug.** `save: {json: {oid: idd}}` saved `None`, logged a warning and requested `/Observation/None`. The test passed against the stub [ran]. Against a real server the next request would likely 404 [inf].
- **The brief's premise about Beda EMR is only partly right.** Of 44 files in `sut/fhir-emr/resources/init-seeds/Mapping/`, 26 are FPML (`type: FHIRPath`), 16 use JUTE syntax (`$let`, `$body`) and 2 are neither [ran: grep]. `allergy-extract.yaml:2` is JUTE. The SUT runs the TypeScript engine pinned at `bedasoftware/fhirpath-extract:0.2.0` [src: `sut/compose.yaml:82`], three published image releases behind 1.0.0 (0.3.0, 0.3.1, 1.0.0) [src: Docker Hub tags, read 2026-11-08].

## What FPML is

"FPML" does expand to FHIRPath Mapping Language [src: METADATA of `fpml-1.0.0`]. It is not HL7's FHIR Mapping Language (FML), which its README positions as the thing it replaces [src: `README:6-8`]. The authors built it by replacing JUTE's path engine with FHIRPath, borrowing Liquid-style delimiters [src: `README:12-20`].

Owner and maintenance [src, from the [GitHub API](https://github.com/beda-software/FHIRPathMappingLanguage) and [PyPI](https://pypi.org/project/fpml/), read 2026-11-08]: Beda Software, MIT. Contributor stats sum to 140 commits across 4 people, 92 of them from one. 21 stars, 13 open issues, last push 2026-09-08. It is not an HL7 standard.

| Implementation | Version | Form |
|---|---|---|
| Python `fpml` | 1.0.0, 2026-09-08 | PyPI library, depends on `fhirpathpy>=2,<3` |
| TypeScript `ts/server` | 1.0.0 (Docker Hub, 2026-09-08) | `private: true` NestJS service, image `bedasoftware/fhirpath-extract`, not an npm library |

The release history has a 14-month gap (0.2.0 in June 2025, 0.3.0 in September 2026), then three releases in four days. 1.0.0 changed the API by replacing `fp_options` with `evaluate` [src: upstream `CHANGELOG.md`, PyPI]. Issue #23 (split into library and server) and #34 (deprecate implicit merge) are open.

| Construct | Behaviour | Source |
|---|---|---|
| `{{ expr }}` | First result, or key removed if empty | `README:202`, `extract.py:174-182` |
| `{[ expr ]}` | All results as an array | `README:221`, `extract.py:167` |
| `{{+ expr +}}` | Empty becomes `null` ("not mature enough") | `README:276-297`, `extract.py:182` |
| `text {{ expr }}` | Interpolation; an empty slot removes the whole string | `README:346-378`, `extract.py:185` |
| `{% if e %}` / `{% else %}` | Conditional object, `e` wrapped in `iif` | `README:437-452`, `extract.py:275,299` |
| `{% for [i,] x in e %}` | Iteration, flattened | `README:480-527`, `extract.py:228` |
| `{% assign %}` | Scoped variables, ordered | `README:381-433`, `extract.py:350` |
| `{% merge %}` | Merge objects | `README:530-554`, `extract.py:329` |
| Pruning and flattening | Empty values, objects and arrays are removed; nested arrays flatten | `README:238-326`, `extract.py:139,155` |

## How op-fhir-middleware uses it

**Contract.** Each mapper is YAML with `context` and `body` [src: `op/docs/decisions/fpml-mappers.md:26-35`]. Read mappers turn OP rows into one FHIR resource and write mappers turn a resource into `{table: [row, ...]}` [src: same file, 41 and 89-93]. FPML "stays a pure transform" and Python owns SQL, transactions and ids [src: same file, 13 and 126-135].

**Invocation.** The runner checks that declared context keys exist, normalizes to JSON, and calls `resolve_template({}, body, context, strict=True, evaluate=evaluate_fhirpath)` with an empty resource [src: `op/app/fhir/mapping/runner.py:52-59`]. Output is validated by the `r4b` class on read or `WriteTables` (non-empty rows) on write [src: `runner.py:18-19,27,35`].

**Extension.** Nine custom functions (`formatFHIRDate`, `formatPhone`, `hasUsableQuantity` and others) are registered through `userInvocationTable`, with compiled expressions cached [src: `op/app/fhir/mapping/fp_options.py:118-171`]. It runs with no FHIR model [src: `fp_options.py:171`], so `value[x]` choice shortcuts are unavailable there [ran: case C8 below].

**Strictness layers, and what each covers:**

| Layer | Catches | Misses |
|---|---|---|
| `strict=True` | Bare paths like `{{ gender }}` [src: `guarded_resource.py:4-10`; ran B4] | Any `%var.path` typo |
| Undefined context variable | `%Regstr` typo [ran; matches [FHIRPath N1 §9](https://hl7.org/fhirpath/N1/)] | Paths under a defined variable |
| Pydantic / `WriteTables` | Wrong shape, missing required elements | An absent optional element [ran] |
| Declared `context` | Missing key at call time [src: `op/tests/test_fpml_mappers.py:17-19`] | Same |

**Blank strings** become null before FPML runs so `.exists()` behaves [src: `runner.py:71-82`, `fpml-mappers.md:57-63`]. That design is a workaround for a truthiness problem, and a test harness would inherit the need for it [inf].

**How mappers are tested.** `op/tests/test_fpml_mappers.py` has three tests: load, missing-context `KeyError`, and a static walk of every read template checking that each `reference` has a `display` [src: `:11-14`, `:17-19`, `:22-57`]. Behaviour is covered by example-based `test_mapper.py` files for 20 resources, each asserting specific fields [src: `op/tests/patient/test_mapper.py:55-62` and siblings].

## How the Python binding behaves

- **API:** `resolve_template(resource, template, context=None, *, strict=False, evaluate=None)`, plus `make_evaluator(model, options)`, `FPOptions`, `Evaluate` and `FPMLValidationError` [src: `extract.py:24-31`, `evaluator.py:17-21`].
- **Extension points:** user functions and models go through an evaluator callback [src: `README:688-741`, `evaluator.py:17-23`]. There is no hook on "slot was empty" [src: `extract.py:181-182`], so empty-handling cannot be customized without forking [inf].
- **Failure:** evaluator exceptions are wrapped as `FPMLValidationError` with a template path, which is a useful message [src: `extract.py:401-402`; ran B1]. Structural misuse also raises [src: `extract.py:280-291`; ran E5].
- **"Empty" versus "wrong":** it cannot distinguish them. A missing element, a mistyped path and a failed `toInteger()` all produce `IndexError` on `[0]` and the same removal [src: `extract.py:178-182`; ran A2, A5, C3].

## Tavern comparison

| Capability | Tavern (3.7.2, pinned at `suites/tavern/requirements.txt:28`) | FPML |
|---|---|---|
| Request and response stages | Yes [src: `tavern/_plugins/rest/response.py:63`; `suites/tavern/tests/test_13_transaction.tavern.yaml:2-32`] | None |
| Status code check | Yes [src: `test_13...yaml:23`] | None |
| Save between stages | `save: json:` (JMESPath), `$ext` [src: `tavern/response.py:201,277-305`; `test_10_crud_patch.tavern.yaml:13-14`] | None. `{% assign %}` is local to one render |
| Variable formatting | Python `{var}`; undefined variable raises `MissingFormatError` [src: `tavern/_core/dict_util.py:29,67-70`; ran] | FHIRPath `%var`; undefined variable raises; undefined *path* is empty [ran] |
| Response matching | Recursive compare, `KeyMismatchError` [src: `dict_util.py:341,435,456`]; `!anything` [src: `dict_util.py:396`], `!re_fullmatch`, `!int` tags [src: `test_11...yaml:21`, `test_02...yaml:30`] | None. Output is data, not a verdict |
| Strict checks | JSON strict by default, set off here [src: `tavern/_core/strict_util.py:51-57`; `suites/tavern/pytest.ini:4`] | Only `strict` for bare paths |
| Runner and pytest | pytest plugin collecting `*.tavern.yaml` [src: repo layout, `tavern/_core/pytest/file.py`] | None |
| External Python | `$ext`, `verify_response_with` receives the `requests.Response` [src: `tavern/response.py:177`, `tavern/_core/extfunctions.py:46,86`; `research/findings.md:33`] | User FHIRPath functions via evaluator |

The overlap is real at one point: `{{ %run_id }}` in a body does the job of `{run_id}`. Everything else differs [inf].

## Role comparison

| Role | Verdict | Evidence |
|---|---|---|
| Replacement for Tavern's YAML | **No** | No request, stage, assertion or collection primitive [src: table above]. Building those means writing a new framework [inf]. |
| Plugin in Tavern (FHIRPath `verify_response_with`, `save`) | **Works, not recommended** | Style B below passes the matrix [ran]. It is 9 YAML lines longer than native matching [ran], builds on the last-ranked suite [src: `REPORT.md:13`], and is FHIRPath, not FPML. An actual FPML template inside a Tavern field fails: `{{ %r.status }}` arrives as `{ %r.status }` because Tavern formats it first [ran]. |
| Response assertions: expected-shape templates | **No** | Pruning removes constraints: style D passes two test bugs silently [ran]. Needs a hand-written comparator [ran]. |
| Response assertions: FHIRPath expressions | **Possible, FHIRPath only** | Requires a helper demanding exactly `[True]`, and it still has vacuous-truth and syntax holes [ran]. |
| Generating request bodies or fixtures | **Not justified** | Works [ran], but an empty slot silently shrinks the body [ran A2, A7], which can make a negative test pass for the wrong reason. The repo records that trap already [src: `REPORT.md:210`]. Current needs are met by a string replace in fixtures [src: `suites/tavern/conftest.py:26`]. |
| Testing the mappers themselves | **Not a tool role; a real gap exists** | FPML is the code under test here. Exact-equality golden tests would catch what field-level tests miss [inf]. A path lint against known columns would extend the existing static walk [src: `op/tests/test_fpml_mappers.py:22-40`; inf]. That work belongs in op-fhir-middleware. |

## Spike: side by side

Source: the first test in `suites/tavern/tests/test_13_transaction.tavern.yaml:2-32`, with `tx_ids` from `suites/tavern/helpers.py:74-77`. All styles ran against a local stub returning canned Aidbox-shaped responses, not the SUT [ran].

The real Tavern assertions:

```yaml
    response:
      status_code: 200
      json: {resourceType: Bundle, type: transaction-response}
      save: {$ext: {function: helpers:tx_ids}}
  - name: Observation points at the created Patient
    request: {url: "{base}/fhir/Observation/{obs_id}", headers: {Authorization: "{admin_auth}"}}
    response:
      status_code: 200
      json: {subject: {reference: "Patient/{patient_id}"}}
```

Closest FPML equivalent, three YAML files plus a Python driver:

```yaml
# tx.request.yaml: identical except one slot
resource: {resourceType: Patient, name: [{family: "{{ %run_id }}-tx"}]}
# tx.save.yaml
patient_id: "{{ %r.entry[0].response.location.split('/_history')[0].split('/').last() }}"
obs_id: "{{ %r.entry[1].response.location.split('/_history')[0].split('/').last() }}"
# tx.expect-observation.yaml
subject:
  reference: "Patient/{{ %patient_id }}"
```

```python
def test_transaction_resolves_references():
    headers = {"Authorization": AUTH}
    r = requests.post(f"{BASE}/fhir", json=render("tx.request.yaml", run_id=RUN_ID), headers=headers)
    assert r.status_code == 200
    subset({"resourceType": "Bundle", "type": "transaction-response"}, r.json())
    saved = render("tx.save.yaml", r=r.json())
    r = requests.get(f"{BASE}/fhir/Observation/{saved['obs_id']}", headers=headers)
    assert r.status_code == 200
    subset(render("tx.expect-observation.yaml", **saved), r.json())
```

The intermediate variant keeps Tavern and moves only the assertions to FHIRPath:

```yaml
    verify_response_with:
      function: fp:check
      extra_kwargs: {asserts: ["%r.subject.reference = 'Patient/{patient_id}'"]}
```

Lines of code, counted as non-blank non-comment [ran: grep, since `bench/loc.sh` needs Docker for cloc]:

| Style | Test-specific | Shared helpers | Total |
|---|---|---|---|
| A Tavern as-is | 31 YAML | 4 (`tx_ids`) | 35 |
| B Tavern + FHIRPath helper | 40 YAML | 14 (`check`, `save`) | 54 |
| C pytest + FPML files | 16 YAML + 9 Python | 21 (imports, `render`, `subset`) | 46 |
| Real pytest case 13, first test | 14 Python | 3 (`ref`) | 17 |

The real pytest test also checks entry statuses and leans on `run` and `admin` fixtures counted elsewhere [src: `suites/pytest/tests/test_13_transaction.py:6-24`; `bench/results-v2/loc.csv`], so the last row is not like for like. The direction is still clear: FPML contributed two interpolations and two extractions, each replaceable by an f-string or a line of Python [inf]. C's HTTP and assertions are all Python, which FPML does not shorten.

## Failure modes

### Direct probes

fpml 1.0.0, fhirpathpy 2.2.4, Python 3.14, resource `{}` with the document in context, as op-fhir-middleware calls it [ran]. Exact output:

| Case | Template | Outcome |
|---|---|---|
| A2 typo in path | `{"resourceType":"Patient","gender":"{{ %r.gendr }}"}` | `{"resourceType":"Patient"}`, no error |
| A3 typo, only key | `{"gender":"{{ %r.gendr }}"}` | `null` |
| A4 typo with `{{+` | `"{{+ %r.gendr +}}"` | `{"gender":null,...}` |
| A5 missing element | `"{{ %r.deceasedBoolean }}"` | Key removed, identical to A2 |
| A6 nested typo | `{"name":[{"given":["{{ %r.name.gven }}"]}]}` | Entire `name` removed |
| A7 typo in embedded | `"Patient/{{ %r.idd }}"` | Key removed (not `Patient/`) |
| B1 undefined variable | `"{{ %rr.gender }}"` | `FPMLValidationError: Cannot evaluate '%rr.gender': Attempting to access an undefined environment variable: rr. Path 'gender'` |
| B3 bare path, non-strict | `"{{ gender }}"` | Key removed |
| B4 bare path, strict | `"{{ gender }}"` | `FPMLValidationError: ... Forbidden access to resource property 'gender' in strict mode. Use context instead.` |
| C1 string + integer | `"{{ %r.gender + 1 }}"` | `FPMLValidationError: ... Cannot [...] + [1]. Path 'v'` |
| C2 boolean vs string | `"{{ %r.active = 'true' }}"` | `false`, no error |
| C3 toInteger on `pat-1` | `"{{ %r.id.toInteger() }}"` | Key removed |
| C8 / C9 choice type | `%qr.item.answer.value` | No model: key removed. r4 model: `"Ilya"` |
| C10 model and typo | `Patient.gendr` with r4 model | Key removed. A model does not catch typos |
| C11 / C12 result types | `1.5`; `active={{ %r.active }}` | `Decimal`; `"active=True"` (Python casing) |
| D1 single braces | `"{ %r.gender }"` | Literal string `"{ %r.gender }"` |
| D3 unbalanced | `"{{ %r.gender }"` | Literal string |
| D5 Tavern syntax | `"{run_id}"` | Literal string |
| E1 directive typo | `{"{% iff %r.active %}":{"a":1}}` | Key kept verbatim in output |
| E3 / E4 `if` on typo | `{% if %r.statsu = 'final' %}` | Branch dropped, or `{% else %}` taken |
| E7 `for` over typo | `{% for x in %r.nmae %}` | Removed |
| F1 multi-value | `"{{ %b.entry.resource.id }}"` | `"mine"`, second entry silently ignored |
| G3 comparison on typo | `"{{ %r.gendr = 'male' }}"` | Key removed: neither true nor false |
| G5 `!=` on typo | `"{{ %r.gendr != 'male' }}"` | Key removed |
| G6 multi-valued equals | `%r.name.given = 'Crud'` | `false`, matches [FHIRPath N1 §11](https://hl7.org/fhirpath/N1/) |
| G7 / G8 / G9 vacuous truth | `%r.nmae.empty()`, `%r.nmae.all(...)`, `where(famly='x').empty()` | `true` on all three |
| H2 hyphen key | `where(eval-result = true)` | `null`, no error. Backticks return the right row (H1). Parsing as subtraction is [inf] |
| H3 / H4 no-crash | `%dump.policies.where(error.exists()).empty()` | `false` correctly; with `erorr`, `true` |

Malformed expressions [ran]: `%r.gender.`, `%r..gender`, `%r.gender)`, `(%r.gender`, `%r.gender 'x'`, `= 'male'` and `%r.gender.first(` all return `"male"`-style results with no error. `%r.gender =`, `1 +`, `%r.name[`, `%r.name.where(` and an unterminated string do raise. Through fhirpathpy directly, `%r.gender = 'male') and false` returns `[True]`.

Spec position: a missing member is an empty collection and empties propagate ([N1 §4.4](https://hl7.org/fhirpath/N1/)). An undefined environment variable is an error (§9). An unresolvable *root* identifier "will end and signal an error" (§3), but fhirpathpy returned empty on schemaless data (B3) [ran; src]. So FPML's silence on a bad member path is spec-conformant FHIRPath, made worse by FPML's pruning [inf].

### Matrix

Five styles, nine scenarios, 45 runs against the stub [ran]. Style D nests saved values under `%saved.x`, a natural way to pass them. Style E is the same with `{{+ +}}`. To make pruning visible, every style also asserted `resourceType: Observation`.

| Scenario | A Tavern | B Tavern + FHIRPath | C FPML, flat ctx | D FPML, `%saved.x` | E FPML, `{{+ +}}` |
|---|---|---|---|---|---|
| Baseline passes | pass | pass | pass | pass | pass |
| SUT: wrong reference | caught | caught | caught | caught | caught |
| SUT: subject missing | caught | caught | caught | caught | caught |
| SUT: wrong type | caught | caught | caught | caught | caught |
| Test: typo in asserted path | caught | caught | caught | caught | caught |
| Test: typo in saved variable at use | caught | caught | caught | **silent pass** | caught |
| Test: typo in save path | caught | caught | caught | **silent pass** | caught |
| Test: single braces in assertion | caught | caught | caught | caught | caught |
| Test: single braces in request body | silent | silent | silent | silent | silent |

Reading this honestly:

- **SUT bugs are caught by every style.** The risk is in test bugs [ran].
- **FPML is not unsafe in every shape.** Style C and E match Tavern, because an undefined `%var` raises and `null` fails the comparison [ran]. The danger is specific: plain `{{ }}` over a path that can be empty, compared by subset. Plain `{{ }}` is the README's default slot form [src: `README:119`].
- **The last row is not FPML-specific.** Each style sent a literal (`{run_id}-tx` or `{ %run_id }-tx`) and nothing asserts that field [ran].
- **FHIRPath messages are good.** `"%r.subject.reference = 'Patient/p-1'" returned [], expected [True]` is clearer than Tavern's mismatch for this case [ran].

### Same-class failures elsewhere

This failure mode is not unique to FPML. The check "no policy crashed" (the kill for mutant 10), run against a dump containing an `error`, then with the field name mistyped as `erorr` [ran]:

| Check | Real field | Mistyped field |
|---|---|---|
| Tavern helper `p.get("error")` (`suites/tavern/helpers.py:19`) | fails, correct | **passes** |
| FHIRPath `.where(error.exists()).empty()` | fails, correct | **passes** |
| Hurl `jsonpath ... not exists` (`suites/hurl/cases/03-sql-error-not-deny.hurl:10`), 8.1.0 | fails, correct | **passes** |

Any negative check on a mistyped field is vacuous in all three. Pruning is the part FPML adds. The repo's positive controls address the vacuous-negative problem: a run-scoped throwing policy proves the crash check can fire [src: `research/findings.md:37`].

Mutants `09-silent-sql-deny` and `10-single-braces-masked` are the SUT-side twins of these. 09 is a path that resolves to nothing with no error, and 10 is single braces reaching the engine as text [src: `sut/mutants/README.md`]. FPML would not change their detection, but it would add the same two failure shapes to the test layer [inf].

## Prior art

| Tool | What it offers | Status of this claim |
|---|---|---|
| [FHIR TestScript](https://hl7.org/fhir/R4B/testscript.html) | Setup, test, teardown, `action.operation`, `action.assert`. `assert.expression` is FHIRPath "against the request or response message contents". Maturity 2, Trial Use | [src] |
| [Touchstone](https://touchstone.aegis.net/touchstone/) | "engineered from the ground up to leverage the new FHIR TestScript resource" | [src] |
| Inferno | `evaluate_fhirpath(resource:, path:, url:)` DSL, evaluated by an external service [src: `inferno-core/lib/inferno/dsl/fhirpath_evaluation.rb:4-8,31`] | [src] |
| HL7 FHIR Validator | A `-fhirpath` option appears only in a FHIR Chat archive post surfaced by web search; the exact thread was not confirmed | Not verified against the CLI |
| [Hurl](https://hurl.dev/docs/asserting-response.html) | 18 query types including `jsonpath`, `xpath`, `regex`; no FHIRPath | [src] |
| Playwright, Karate, pytest | `fhirpath.js` or `fhirpathpy` usable in the test language | [src: `research/scorecard.md:41,85`] |
| FPML-based test tooling | None surfaced in a targeted web search | [inf] from absence |

The pattern in the FHIR world is FHIRPath as an assertion expression inside a real test construct. TestScript is the closest thing to what the hypothesis imagines. FHIRPath is used there as an expression language, not a template language [inf].

## Minimal adoption, if any

None for FPML. For FHIRPath, if the measurement below supports it, about 14 lines in the pytest suite [ran: the `check`/`save` pair, counted with its import]:

```python
def fp_true(body, expr):
    got = evaluate({}, expr, {"r": body})
    assert got == [True], f"{expr!r} returned {got!r}, expected [True]"
```

Rules it would need:

1. Require exactly `[True]`, never truthiness. Empty must fail [ran: B catches typo].
2. Save exactly one value or fail [ran].
3. Avoid `.empty()`, `.all()` and `not` as sole assertions, or pair each with a positive control [ran: G7-G9].
4. Pass a model when using `value[x]` shortcuts [ran: C8, C9].
5. Know that malformed expressions can parse [ran]. A linter or a patched error listener is an open question.

## Evaluation with bench

Nothing here was run: it needs the Docker SUT. It is a plan.

1. Add a suite variant by copying `suites/pytest` to `suites/pytest-fhirpath`, converting assertions on FHIR bodies and dumps to `fp_true`, and registering it in `bench/lib.sh:3` and `suite_cmd` [src: `bench/lib.sh:3,9-23`].
2. Run `bench/mutants.sh` over `sut/mutants` (15) and, with `MUTANTS_DIR`, over `sut/mutants-holdout` (12) [src: `bench/mutants.sh:4,14`]. Predicted result: the same kills as pytest [inf].
3. **Add what these mutants cannot measure.** They mutate policies, so they cannot test assertion robustness [src: `sut/mutants/README.md:3-7`]. A test-mutation pass, modelled on `bench/ablate.sh:2`, would mistype one path per assertion in a copy of each suite and run it against the unmodified SUT. Survivors are silent-pass assertions. Predicted: `.get()`, JMESPath and `.empty()` checks survive, while positive equality fails [inf from the spike].
4. Decide by rules set before the run: adopt only if kills are at least pytest's, typo survival is no worse than pytest's, LOC from `bench/loc.sh` is no worse, and diagnosis is no worse (`bench/diagnose_prep.sh`).

An expected-shape FPML variant can be added to step 3 at low cost if anyone wants the comparison measured rather than taken from the stub. I would not expect it to win [inf].

## Limits and open questions

**Not verified:**

- The TypeScript engine was not run, so cross-implementation behaviour (such as Python's `True` casing versus JavaScript) is inferred. The SUT uses that engine, at 0.2.0.
- No test ran against Aidbox or the real SUT. The matrix used a stub with canned responses, and one test was ported (N = 1, author-chosen scenarios).
- The Validator's `-fhirpath` flag rests on one chat post. The HL7 Confluence page returned 405 and the help file could not be fetched.
- TestScript's current R6 status is unconfirmed (404 on the CI build); the citation is R4B.
- Tavern's strict-checking docs page was not retrieved. Those claims rest on the 3.7.2 source.
- LOC was counted with grep, not `bench/loc.sh`'s cloc, so counts are not directly comparable to `bench/results-v2/loc.csv`.

**Open questions:**

1. Is the fhirpathpy parser's behaviour known upstream, and would an EOF-anchored parse break callers? It affects the production mappers as well as any assertion use.
2. Does op-fhir-middleware want golden tests or a context-path lint for mapper typos on optional fields? That is a decision for that repo.
3. Are FHIR-shaped assertions common enough in new pytest tests to justify `fp_true` at all, given comprehensions already work there? The bake-off suites used no FHIR library [src: `REPORT.md:143`].

Raw spike output and scripts for this session are in `/tmp/claude-1000/-home-alex-prj-personal-testing-frameworks-research/bd9d51cf-75f5-4e01-a248-3ad4e78ffbf3/scratchpad/fpml-spike/` (`out/failure-modes.txt`, `out/matrix.txt`, `out/matrix/logs/`, `scripts/`). That directory is temporary and is not part of this repo.
