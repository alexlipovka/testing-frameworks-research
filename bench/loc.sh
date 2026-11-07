#!/bin/sh
# cloc per suite and per case -> results/loc-by-file.csv, results/loc.csv.
# Every git-tracked file under suites/<name>/ (runners included) except docs (*.md)
# and dependency lockfiles (package-lock.json, requirements.txt).
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
. "$REPO/bench/lib.sh"
CLOC=aldanial/cloc@sha256:54d1304dc3b80eec8efb2d9bb96d41e508987405f2eff8c1818ddf461e943597
OUT=$REPO/bench/results
cd "$REPO"
git ls-files $(printf 'suites/%s ' $SUITES) | grep -vE '\.md$|package-lock\.json$|requirements\.txt$' > "$OUT/.loc-files"
# cloc has no Hurl definition; matrix/table.txt is Hurl's case 8 data, with # comments too
docker run --rm -v "$REPO:/r:ro" -w /r $CLOC --quiet --by-file --csv --read-lang-def=bench/hurl.lang \
  --force-lang=Hurl,txt --list-file=bench/results/.loc-files \
  | grep -E '^[^,]+,suites/' > "$OUT/loc-by-file.csv"
cut -d, -f2 "$OUT/loc-by-file.csv" | sort > "$OUT/.loc-counted"
missed=$(sort "$OUT/.loc-files" | comm -23 - "$OUT/.loc-counted")
[ -z "$missed" ] || echo "not counted by cloc (no code or unknown type):" $missed >&2
rm "$OUT/.loc-files" "$OUT/.loc-counted"
python3 - "$OUT" <<'PY'
import csv, re, sys, collections
out = sys.argv[1]
agg = collections.defaultdict(lambda: [0, 0])
for lang, path, blank, comment, code in csv.reader(open(f"{out}/loc-by-file.csv")):
    suite, rest = path.split("/")[1], "/".join(path.split("/")[2:])
    m = re.match(r"(?:test_)?(\d\d)[-_]", rest.split("/")[-1])
    case = m.group(1) if m else "08" if rest.startswith("matrix/") else "shared"
    agg[(suite, case)][0] += 1
    agg[(suite, case)][1] += int(code)
with open(f"{out}/loc.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["suite", "case", "files", "code"])
    for (suite, case), (n, code) in sorted(agg.items()):
        w.writerow([suite, case, n, code])
PY
echo "wrote $OUT/loc.csv"
