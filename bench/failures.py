"""failures.py SUITE_DIR LOG SINCE: the failing tests of one run, from JUnit XML and
Hurl's matrix rows in the log; NO_REPORT if none was written. Reports older than
SINCE are stale: pytest writes them as root, so the bench cannot delete them."""
import glob
import os
import re
import sys
import xml.etree.ElementTree as ET

suite_dir, log, since = sys.argv[1], sys.argv[2], float(sys.argv[3])
reports = {
    "hurl": [".junit.xml"],
    "karate": ["target/karate-reports/junit-xml/*.xml"],
    "pytest": ["reports/junit-1.xml"],
    "playwright": ["reports/junit.xml"],
    "tavern": [".run/junit.xml"],
    "aidbox-sdk": ["reports/junit.xml"],
}[suite_dir.rstrip("/").split("/")[-1]]
files = [f for pattern in reports for f in glob.glob(f"{suite_dir}/{pattern}") if os.path.getmtime(f) >= since]
failed = set()
for f in files:
    for case in ET.parse(f).iter("testcase"):
        if case.find("failure") is not None or case.find("error") is not None:
            failed.add(f"{case.get('classname', '')}::{case.get('name', '')}".strip(":"))
failed |= {f"matrix::{row}" for row in re.findall(r"^matrix row: (\S+)", open(log).read(), re.M)}
if not files:
    failed.add("NO_REPORT")
print("\n".join(sorted(failed)))
