"""Case 14: run_id isolation: this run sees only its own fixtures; another run's ids are out of reach."""
from aidbox import expect_deny


def test_no_rows_from_other_runs(run, admin):
    r = admin.get("/fhir/Patient?family:exact=Bakeoff&_count=100")
    assert r.status_code == 200, r.text
    got = {e["resource"]["id"] for e in r.json().get("entry", [])}
    assert got == {run.id(n) for n in ("patient-self", "patient-other", "patient-unlinked")}


def test_same_fixture_name_from_another_run_is_denied(run, admin, pat_self):
    foreign = "bakeoff-otherrun-patient-self"
    assert admin.put(f"/fhir/Patient/{foreign}", json={"resourceType": "Patient", "id": foreign}).is_success
    expect_deny(pat_self, "GET", f"/fhir/Patient/{foreign}")
