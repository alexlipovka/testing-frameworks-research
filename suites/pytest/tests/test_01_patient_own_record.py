"""Case 1: a patient reads their own Patient (matcho policy), not someone else's."""
from aidbox import expect_allow, expect_deny


def test_patient_reads_own_record(run, pat_self):
    r = expect_allow(pat_self, "GET", f"/fhir/Patient/{run.id('patient-self')}", by="patient-role-policy")
    assert r.json()["id"] == run.id("patient-self")


def test_patient_cannot_read_other_record(run, pat_self):
    expect_deny(pat_self, "GET", f"/fhir/Patient/{run.id('patient-other')}")
