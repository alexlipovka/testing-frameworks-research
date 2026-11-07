# Karate suite

Karate 2.1.4 (standalone jar, sha256-pinned in `run.sh`) on `eclipse-temurin:21.0.8_9-jre` in Docker.
No Maven or Gradle.

```sh
./run.sh                 # setup, all 15 cases on 4 threads, teardown (always)
./run.sh twice           # case 15: two consecutive runs, both green
THREADS=1 ./run.sh       # sequential
./run.sh teardown        # close a run left open (.vars.json)
```

Reports: `target/karate-reports/karate-summary.html` (request/response per step) and `junit-xml/`.

## Layout

- `karate-config.js` opens the run once per JVM with `karate.callSingle`. Every scenario gets
  `runId`, `id(name)` (`<run_id>-<name>`), `bearer(identity)` and `adminAuth`.
- `fixtures/setup.feature` follows `sut/fixtures/README.md`: stamp, `.vars.json`, setup, 5 tokens.
- `fixtures/teardown.feature` rolls back to the stamp. Karate has no after-suite hook, so `run.sh` runs it
  in a second JVM from an `EXIT` trap.
- `lib/ap.feature` sends a request twice: once with `__debug=policy`, returning `allowedBy` (the policies with
  `eval-result: true`) and `crashed` (the policies with an `error`), and once for real, returning `status`
  and `response`.
- `features/NN-*.feature`: one file per spec case.
