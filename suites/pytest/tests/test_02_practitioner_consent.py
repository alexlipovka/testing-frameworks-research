"""Case 2: a practitioner reads a Patient through an active Consent (SQL policy); a revoked one denies."""
import pytest

from aidbox import expect_allow, expect_deny


@pytest.mark.parametrize("who, patient", [("p1", "patient-self"), ("p2", "patient-other")])
def test_active_consent_allows(run, who, patient):
    r = expect_allow(run.clients[who], "GET", f"/fhir/Patient/{run.id(patient)}", by="practitioner-policy")
    assert r.json()["id"] == run.id(patient)


def test_revoked_consent_denies(run, p1):
    expect_deny(p1, "GET", f"/fhir/Patient/{run.id('patient-other')}")


def test_no_consent_denies(run, p1, p2):
    expect_deny(p1, "GET", f"/fhir/Patient/{run.id('patient-unlinked')}")
    expect_deny(p2, "GET", f"/fhir/Patient/{run.id('patient-self')}")
