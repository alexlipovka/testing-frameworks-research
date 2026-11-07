#!/bin/sh
# ablate.sh DIR: copy the repo to DIR with every policy-decision assertion removed.
# A mutant only the real suite kills is caught by a decision assertion alone.
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
DEST=$1
# pytest's runner writes its reports as root; only a container can remove them
[ ! -e "$DEST" ] || docker run --rm -v "$(dirname "$DEST"):/p" python:3.12.12-slim rm -rf "/p/$(basename "$DEST")"
mkdir -p "$DEST"
rsync -a --exclude .git --exclude node_modules --exclude target --exclude reports --exclude .run \
  --exclude __pycache__ --exclude sut/fhir-emr --exclude sut/build "$REPO/" "$DEST/"
python3 - "$DEST/suites" <<'PY'
import re, sys, glob, os
os.chdir(sys.argv[1])
def patch(pattern, files, fn):
    n = 0
    for f in sorted(glob.glob(files)):
        s = open(f).read()
        new = fn(s)
        if new != s:
            n += 1
            open(f, "w").write(new)
    assert n, f"ablation {pattern!r} changed nothing in {files}"
drop = lambda rx: (lambda s: re.sub(rx, "", s, flags=re.M))
# Hurl: every assert on the __debug=policy dump
patch("hurl", "hurl/cases/*.hurl", drop(r'^jsonpath "\$\.policies.*\n'))
# Karate: matches on allowedBy / crashed, and the matrix's decision terms
patch("karate", "karate/features/*.feature", drop(r'^\s*\* match (r\.(allowedBy|crashed)|karate\.toString\(r\.crashed).*\n'))
patch("karate matrix", "karate/features/08-matrix.feature",
      lambda s: s.replace("JSON.stringify(r.allowedBy) == JSON.stringify(want) && r.crashed.length == 0\n        && ", ""))
# pytest: verdict assertions in the helpers and in case 3
patch("pytest", "pytest/aidbox.py", drop(r'^\s*(assert (not )?v\.allowed|if by:\n\s*assert by in v\.allowed_by).*\n'))
patch("pytest 03", "pytest/tests/test_03_policy_error.py", drop(r'^\s*assert (not v\.allowed|\[e\["id"\] for e in v\.errors\]).*\n'))
# Playwright: expect() on the verdict
patch("playwright", "playwright/lib/*.ts", drop(r'^\s*expect\(v\.(granted|errors).*\n'))
patch("playwright", "playwright/tests/*.ts", drop(r'^\s*expect\(v\.(granted|errors).*\n'))
# Tavern: the debug-dump verifiers become no-ops
patch("tavern", "tavern/helpers.py",
      lambda s: re.sub(r'(def (decision|crashed|no_crash)\(.*\):\n(    """.*"""\n)?)', r'\1    return\n', s))
PY
echo "ablated copy in $DEST"
