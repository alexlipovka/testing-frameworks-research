"""mutants_report.py RESULTS: mutants.csv -> mutant-matrix.csv and a Markdown table. Killed: a test
fails in both mutant runs and never failed at baseline (a known flake). Decision-only:
killed, but the decision-ablated copy shows no such failure."""
import collections
import csv
import re
import sys

OUT = sys.argv[1]
SUITES = ["hurl", "karate", "pytest", "playwright", "tavern"]
runs = collections.defaultdict(dict)
for r in csv.DictReader(open(f"{OUT}/mutants.csv")):
    # Parametrized test names carry the run_id, which differs per run
    tests = {re.sub(r"bakeoff-[0-9a-f]{8}", "{run}", t) for t in r["failed_tests"].split(";") if t}
    runs[(r["mutant"], r["suite"])][r["run"]] = (int(r["exit"]), tests)

flaky = collections.defaultdict(set)
for (m, s), rr in runs.items():
    for run, (_, tests) in rr.items():
        if run.startswith("baseline"):
            flaky[s] |= tests

rows = []
for (m, s), rr in sorted(runs.items()):
    (e1, t1), (e2, t2), (ea, ta) = rr["mutant1"], rr["mutant2"], rr["ablated"]
    kill = (t1 & t2) - flaky[s]
    status_kill = ta - flaky[s]
    notes = []
    red = [run for run, (e, _) in rr.items() if run.startswith("baseline") and e]
    if red:
        tests = set().union(*(rr[run][1] for run in red))
        notes.append(f"baseline red {len(red)}x: {';'.join(sorted(tests))}")
    if t1 - flaky[s] != t2 - flaky[s]:
        notes.append(f"mutant runs differ: {';'.join(sorted((t1 ^ t2) - flaky[s]))}")
    if (t1 | t2 | ta) & flaky[s]:
        notes.append(f"known flake also failed: {';'.join(sorted((t1 | t2 | ta) & flaky[s]))}")
    if bool(e1) != bool(t1) or bool(e2) != bool(t2):
        notes.append(f"exit/report mismatch: exits {e1},{e2}")
    rows.append({"mutant": m, "suite": s, "killed": int(bool(kill)),
                 "decision_only": int(bool(kill) and not status_kill),
                 "killing_tests": ";".join(sorted(kill)), "notes": " | ".join(notes)})

with open(f"{OUT}/mutant-matrix.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0]))
    w.writeheader()
    w.writerows(rows)

by = {(r["mutant"], r["suite"]): r for r in rows}
mutants = sorted({r["mutant"] for r in rows})
mark = lambda r: "—" if not r else ("●" if r["decision_only"] else "✓") if r["killed"] else "✗"
print("| Mutant | " + " | ".join(SUITES) + " |")
print("|---|" + "---|" * len(SUITES))
for m in mutants:
    print(f"| {m} | " + " | ".join(mark(by.get((m, s))) for s in SUITES) + " |")
kills = [sum(by[(m, s)]["killed"] for m in mutants if (m, s) in by) for s in SUITES]
dec = [sum(by[(m, s)]["decision_only"] for m in mutants if (m, s) in by) for s in SUITES]
print(f"| **Killed** | " + " | ".join(f"**{k}/{len(mutants)}**" for k in kills) + " |")
print(f"| of which decision-only | " + " | ".join(str(d) for d in dec) + " |")
print()
for s in SUITES:
    if flaky[s]:
        print(f"- known flakes ({s}): {'; '.join(sorted(flaky[s]))}", file=sys.stderr)
