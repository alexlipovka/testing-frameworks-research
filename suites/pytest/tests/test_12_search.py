"""Case 12: search with _include, _revinclude and chaining."""


def entries(r):
    assert r.status_code == 200, r.text
    return {f"{e['resource']['resourceType']}/{e['resource']['id']}": e.get("search", {}).get("mode")
            for e in r.json().get("entry", [])}


def test_include(run, admin):
    got = entries(admin.get(f"/fhir/Encounter?_id={run.id('enc-match')}&_include=Encounter:subject"))
    assert got == {f"Encounter/{run.id('enc-match')}": "match", f"Patient/{run.id('patient-self')}": "include"}


def test_revinclude(run, admin):
    got = entries(admin.get(f"/fhir/Patient?_id={run.id('patient-self')}&_revinclude=Observation:subject"))
    assert got == {f"Patient/{run.id('patient-self')}": "match", f"Observation/{run.id('obs-match')}": "include"}


def test_chaining(run, admin):
    got = entries(admin.get("/fhir/Encounter?subject:Patient.given=Self"))
    assert f"Encounter/{run.id('enc-match')}" in got
    assert f"Encounter/{run.id('enc-mismatch')}" not in got
