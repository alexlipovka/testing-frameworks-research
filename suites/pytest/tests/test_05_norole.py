"""Case 5: an identity with no role is denied everywhere."""
import pytest

from aidbox import expect_deny

REQUESTS = [
    ("GET", "/fhir/Patient/{patient-self}", None),
    ("GET", "/fhir/Patient?_id={patient-self}", None),
    ("GET", "/fhir/Encounter/{enc-match}", None),
    ("GET", "/fhir/Observation?subject=Patient/{patient-self}", None),
    ("GET", "/fhir/Appointment/{appt-match}", None),
    ("PUT", "/fhir/Patient/{patient-self}", {"resourceType": "Patient", "id": "{patient-self}"}),
    ("POST", "/fhir/Appointment", {"resourceType": "Appointment", "status": "proposed",
                                   "participant": [{"actor": {"reference": "Patient/{patient-self}"}, "status": "needs-action"}]}),
    ("POST", "/fhir/Questionnaire/glucose/$populate",
     {"resourceType": "Parameters", "parameter": [{"name": "subject", "valueReference": {"reference": "Patient/{patient-self}"}}]}),
    ("POST", "/fhir", {"resourceType": "Bundle", "type": "transaction",
                       "entry": [{"request": {"method": "GET", "url": "Patient/{patient-self}"}}]}),
]


def fill(run, x):
    if isinstance(x, str):
        for name in ("patient-self", "enc-match", "appt-match"):
            x = x.replace("{" + name + "}", run.id(name))
        return x
    if isinstance(x, dict):
        return {k: fill(run, v) for k, v in x.items()}
    if isinstance(x, list):
        return [fill(run, v) for v in x]
    return x


@pytest.mark.parametrize("method, url, body", REQUESTS, ids=[f"{m} {u}" for m, u, _ in REQUESTS])
def test_norole_denied(run, norole, method, url, body):
    kw = {"json": fill(run, body)} if body else {}
    expect_deny(norole, method, fill(run, url), **kw)
