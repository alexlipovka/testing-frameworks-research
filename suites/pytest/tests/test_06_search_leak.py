"""Case 6: allowed searches return nothing outside the caller's scope; out-of-scope searches are denied."""
from aidbox import expect_allow, expect_deny


def ids(r):
    return {f"{e['resource']['resourceType']}/{e['resource']['id']}" for e in r.json().get("entry", [])}


def test_patient_searches_only_own_observations(run, pat_self):
    for subject in (f"Patient/{run.id('patient-self')}", run.id("patient-self")):
        r = expect_allow(pat_self, "GET", f"/fhir/Observation?subject={subject}")
        assert ids(r) == {f"Observation/{run.id('obs-match')}"}


def test_patient_out_of_scope_searches_denied(run, pat_self):
    expect_deny(pat_self, "GET", f"/fhir/Observation?subject=Patient/{run.id('patient-other')}")
    expect_deny(pat_self, "GET", "/fhir/Observation")
    expect_deny(pat_self, "GET", f"/fhir/Observation?subject=Patient/{run.id('patient-self')}"
                                 f"&subject=Patient/{run.id('patient-other')}")
    expect_deny(pat_self, "GET", f"/fhir/Observation?subject=Patient/{run.id('patient-self')}"
                                 "&_include=Observation:subject")


def test_practitioner_searches_only_consented_patients(run, p1):
    r = expect_allow(p1, "GET", f"/fhir/Patient?_id={run.id('patient-self')}")
    assert ids(r) == {f"Patient/{run.id('patient-self')}"}
    expect_deny(p1, "GET", f"/fhir/Patient?_id={run.id('patient-self')},{run.id('patient-other')}")
    expect_deny(p1, "GET", "/fhir/Patient")


def test_receptionist_search_has_no_includes(run, rec):
    r = expect_allow(rec, "GET", f"/fhir/Patient?_id={run.id('patient-self')}")
    assert ids(r) == {f"Patient/{run.id('patient-self')}"}
    expect_deny(rec, "GET", f"/fhir/Patient?_id={run.id('patient-self')}&_revinclude=Observation:subject")
    expect_deny(rec, "GET", f"/fhir/Appointment?_id={run.id('appt-match')}&_include=Appointment:actor")
