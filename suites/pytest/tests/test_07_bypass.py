"""Case 7: writes and reads denied directly stay denied via transaction Bundle, JSON Patch, merge-patch."""
import json

from aidbox import expect_deny


def assert_untouched(run, admin):
    assert admin.get(f"/fhir/Patient/{run.id('patient-self')}").json()["name"][0]["family"] == "Bakeoff"


def test_transaction_bundle_denied(run, rec, pat_self, admin):
    pid = run.id("patient-self")
    expect_deny(rec, "POST", "/fhir", json={"resourceType": "Bundle", "type": "transaction", "entry": [{
        "resource": {"resourceType": "Patient", "id": pid, "name": [{"family": "Hacked"}]},
        "request": {"method": "PUT", "url": f"Patient/{pid}"}}]})
    expect_deny(pat_self, "POST", "/fhir", json={"resourceType": "Bundle", "type": "batch", "entry": [{
        "request": {"method": "GET", "url": f"Patient/{run.id('patient-other')}"}}]})
    assert_untouched(run, admin)


def test_json_patch_denied(run, rec, p1, admin):
    patch = json.dumps([{"op": "replace", "path": "/name/0/family", "value": "Hacked"}])
    for c in (rec, p1):
        expect_deny(c, "PATCH", f"/fhir/Patient/{run.id('patient-self')}",
                    headers={"Content-Type": "application/json-patch+json"}, content=patch)
    assert_untouched(run, admin)


def test_merge_patch_denied(run, rec, admin):
    expect_deny(rec, "PATCH", f"/fhir/Patient/{run.id('patient-self')}",
                headers={"Content-Type": "application/merge-patch+json"},
                content=json.dumps({"name": [{"family": "Hacked"}]}))
    assert_untouched(run, admin)
