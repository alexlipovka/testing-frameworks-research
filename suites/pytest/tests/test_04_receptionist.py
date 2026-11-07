"""Case 4: a receptionist reads Patients but cannot write them (PUT, POST, JSON Patch)."""
import json

from aidbox import expect_allow, expect_deny

JSON_PATCH = {"Content-Type": "application/json-patch+json"}


def test_receptionist_reads_patients(run, rec):
    r = expect_allow(rec, "GET", f"/fhir/Patient/{run.id('patient-self')}", by="as-receptionist-read-patients")
    assert r.json()["id"] == run.id("patient-self")
    r = expect_allow(rec, "GET", f"/fhir/Patient?_id={run.id('patient-other')}", by="as-receptionist-read-patients")
    assert [e["resource"]["id"] for e in r.json()["entry"]] == [run.id("patient-other")]


def test_receptionist_cannot_write_patients(run, rec, admin):
    pid = run.id("patient-self")
    renamed = {"resourceType": "Patient", "id": pid, "name": [{"family": "Hacked"}]}
    expect_deny(rec, "PUT", f"/fhir/Patient/{pid}", json=renamed)
    expect_deny(rec, "POST", "/fhir/Patient", json={"resourceType": "Patient", "name": [{"family": "Hacked"}]})
    expect_deny(rec, "PATCH", f"/fhir/Patient/{pid}", headers=JSON_PATCH,
                content=json.dumps([{"op": "replace", "path": "/name/0/family", "value": "Hacked"}]))
    assert admin.get(f"/fhir/Patient/{pid}").json()["name"][0]["family"] == "Bakeoff"
