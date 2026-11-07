"""Case 11: an invalid resource is rejected with an OperationOutcome."""
import pytest


@pytest.mark.parametrize("body", [
    {"resourceType": "Patient", "birthDate": "not-a-date"},
    {"resourceType": "Patient", "unknownElement": 1},
], ids=["bad-date", "unknown-element"])
def test_invalid_patient_rejected(admin, body):
    r = admin.post("/fhir/Patient", json=body)
    assert r.status_code == 422, r.text
    oo = r.json()
    assert oo["resourceType"] == "OperationOutcome"
    assert oo["issue"] and all(i["severity"] in ("error", "fatal") for i in oo["issue"])
