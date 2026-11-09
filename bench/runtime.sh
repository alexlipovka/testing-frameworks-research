#!/bin/sh
# runtime.sh [floor|warm|cold ...]: hyperfine, 10 runs per suite and mode, one at a time.
# warm: after one untimed run. cold: Aidbox restarted before each run. floor: no-op
# start of each runner image. Every suite run is a fresh container (runtime startup in).
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
. "$REPO/bench/lib.sh"
OUT=$RESULTS/runtime
HF=$REPO/bench/.tools/hyperfine
HF_URL=https://github.com/sharkdp/hyperfine/releases/download/v1.19.0/hyperfine-v1.19.0-x86_64-unknown-linux-musl.tar.gz
HF_SHA=825287143f397774093539ca2458854ab3735c0e8a1aaf075c22edce7d261556
mkdir -p "$OUT"
if [ ! -x "$HF" ]; then
  mkdir -p "$(dirname "$HF")"
  curl -sfL -o "$HF.tgz" "$HF_URL"
  echo "$HF_SHA  $HF.tgz" | sha256sum -c --status || { echo "hyperfine checksum mismatch" >&2; exit 1; }
  tar xzf "$HF.tgz" -C "$(dirname "$HF")" --strip-components=1 hyperfine-v1.19.0-x86_64-unknown-linux-musl/hyperfine
  rm "$HF.tgz"
fi
B="REPO=$REPO; . $REPO/bench/lib.sh"

floor() {
  "$HF" -N --warmup 1 --runs 10 --export-json "$OUT/floor.json" \
    -n hurl "docker run --rm ghcr.io/orange-opensource/hurl:8.1.0 --version" \
    -n karate "docker run --rm eclipse-temurin:21.0.8_9-jre java -version" \
    -n pytest "docker run --rm bakeoff-pytest --version" \
    -n playwright "docker run --rm bakeoff-playwright:1.65.0 --version" \
    -n tavern "docker run --rm bakeoff-tavern:3.7.2 --version" \
    -n aidbox-sdk "docker run --rm bakeoff-aidbox-sdk --version"
}

suites() {
  cond=$1; shift
  for s in $SUITES; do
    for mode in seq par; do
      cmd=$(suite_cmd "$s" "$mode") || continue
      "$REPO/sut/mutants/revert.sh" >/dev/null
      assert_no_open_run
      # -i: a failing run is still timed; its exit code lands in the JSON
      "$HF" -i --runs 10 --export-json "$OUT/$s-$mode-$cond.json" -n "$s $mode $cond" \
        --conclude "$B; assert_no_open_run" "$@" "$cmd" 2>&1 | grep -vE '^\s*$'
    done
  done
}

for what in ${*:-floor warm cold}; do
  case $what in
    floor) floor ;;
    warm) suites warm --warmup 1 ;;
    cold) suites cold --prepare "$B; restart_aidbox" ;;
  esac
done
python3 - "$OUT" <<'PY'
import glob, json, os, sys
out = sys.argv[1]
rows = ["suite,mode,condition,runs,failed,mean_s,stddev_s,median_s,min_s,max_s"]
for f in sorted(glob.glob(f"{out}/*.json")):
    for r in json.load(open(f))["results"]:
        name = r["command"].split()
        suite, mode, cond = (name + ["", ""])[:3] if len(name) == 3 else (name[0], "-", "floor")
        failed = sum(1 for c in r.get("exit_codes", []) if c)
        rows.append(f"{suite},{mode},{cond},{len(r['times'])},{failed},"
                    + ",".join(f"{r[k]:.2f}" for k in ("mean", "stddev", "median", "min", "max")))
open(f"{os.path.dirname(out)}/runtime.csv", "w").write("\n".join(rows) + "\n")
print("\n".join(rows))
PY
