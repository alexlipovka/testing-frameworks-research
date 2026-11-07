"""Case 13: transaction Bundles resolve urn:uuid references and are all-or-nothing."""
import re
import uuid


def ref(location):
    """`http://host/fhir/Observation/<id>/_history/<v>` -> `Observation/<id>`"""
    return re.search(r"/fhir/(\w+/[^/]+)/_history/", location).group(1)


def test_urn_references_resolved(run, admin):
    pat = f"urn:uuid:{uuid.uuid4()}"
    r = admin.post("/fhir", json={"resourceType": "Bundle", "type": "transaction", "entry": [
        {"fullUrl": pat, "resource": {"resourceType": "Patient", "name": [{"family": "Tx"}]},
         "request": {"method": "POST", "url": "Patient"}},
        {"resource": {"resourceType": "Observation", "status": "final", "code": {"text": "Tx"},
                      "subject": {"reference": pat}},
         "request": {"method": "POST", "url": "Observation"}}]})
    assert r.status_code == 200, r.text
    out = r.json()
    assert out["type"] == "transaction-response"
    assert [e["response"]["status"][:3] for e in out["entry"]] == ["201", "201"]
    patient_ref, obs_ref = (ref(e["response"]["location"]) for e in out["entry"])
    assert admin.get(f"/fhir/{obs_ref}").json()["subject"]["reference"] == patient_ref


def test_failed_entry_rolls_back_whole_bundle(run, admin):
    pid = run.id("tx-rollback")
    r = admin.post("/fhir", json={"resourceType": "Bundle", "type": "transaction", "entry": [
        {"resource": {"resourceType": "Patient", "id": pid}, "request": {"method": "PUT", "url": f"Patient/{pid}"}},
        {"resource": {"resourceType": "Patient", "birthDate": "not-a-date"}, "request": {"method": "POST", "url": "Patient"}}]})
    assert 400 <= r.status_code < 500, r.text
    assert admin.get(f"/fhir/Patient/{pid}").status_code in (404, 410)
