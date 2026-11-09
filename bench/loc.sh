#!/bin/sh
# cloc per suite and per case -> $RESULTS/loc-by-file.csv, loc.csv, and loc-added.csv
# against the first draft (bench/results/loc.csv, git diff from FIRST_DRAFT).
# Every git-tracked file under suites/<name>/ (runners included) except docs (*.md)
# and dependency lockfiles (package-lock.json, requirements.txt, pyproject.toml, uv.lock).
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
. "$REPO/bench/lib.sh"
CLOC=aldanial/cloc@sha256:54d1304dc3b80eec8efb2d9bb96d41e508987405f2eff8c1818ddf461e943597
OUT=$RESULTS
FIRST_DRAFT=aaa401c
cd "$REPO"
mkdir -p "$OUT"
rel=${OUT#"$REPO"/}
git ls-files $(printf 'suites/%s ' $SUITES) | grep -vE '\.md$|package-lock\.json$|requirements\.txt$|pyproject\.toml$|uv\.lock$' > "$OUT/.loc-files"
# cloc has no Hurl definition; matrix/table.txt is Hurl's case 8 data, with # comments too
docker run --rm -v "$REPO:/r:ro" -w /r $CLOC --quiet --by-file --csv --read-lang-def=bench/hurl.lang \
  --force-lang=Hurl,txt --list-file="$rel/.loc-files" \
  | grep -E '^[^,]+,suites/' > "$OUT/loc-by-file.csv"
cut -d, -f2 "$OUT/loc-by-file.csv" | sort > "$OUT/.loc-counted"
missed=$(sort "$OUT/.loc-files" | comm -23 - "$OUT/.loc-counted")
[ -z "$missed" ] || echo "not counted by cloc (no code or unknown type):" $missed >&2
rm "$OUT/.loc-files" "$OUT/.loc-counted"
git diff --numstat "$FIRST_DRAFT" HEAD -- $(printf 'suites/%s ' $SUITES) \
  | grep -vE '\.md$|package-lock\.json$|requirements\.txt$|pyproject\.toml$|uv\.lock$' > "$OUT/.loc-numstat"
python3 - "$OUT" "$REPO/bench/results/loc.csv" <<'PY'
import csv, os, re, sys, collections
out, first = sys.argv[1:3]
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
total = lambda rows: sum(int(r["code"]) for r in rows)
draft = list(csv.DictReader(open(first)))
best = list(csv.DictReader(open(f"{out}/loc.csv")))
git = collections.Counter()
for line in open(f"{out}/.loc-numstat"):
    added, removed, path = line.rstrip("\n").split("\t")
    git[path.split("/")[1], "added"] += int(added)
    git[path.split("/")[1], "removed"] += int(removed)
os.remove(f"{out}/.loc-numstat")
with open(f"{out}/loc-added.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["suite", "first_draft_code", "best_state_code", "code_added_net", "git_lines_added", "git_lines_removed"])
    for s in sorted({r["suite"] for r in best}):
        d, b = total(r for r in draft if r["suite"] == s), total(r for r in best if r["suite"] == s)
        w.writerow([s, d, b, b - d, git[s, "added"], git[s, "removed"]])
PY
echo "wrote $OUT/loc.csv"
