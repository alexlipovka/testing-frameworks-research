"""Case 9: $populate / $extract gated per role, forged answers and QR subject ownership.

Allowed calls assert only that the policy gate passed: the SUT lacks fhir-emr's launch context,
so the mapping output is not checked.
"""
import pytest

from aidbox import expect_allow, expect_deny

POPULATE = "/fhir/Questionnaire/glucose/$populate"
EXTRACT = "/fhir/Questionnaire/glucose/$extract"


def populate(run, patient):
    return {"resourceType": "Parameters", "parameter": [
        {"name": "subject", "valueReference": {"reference": f"Patient/{run.id(patient)}"}}]}


def extract(run, subject, answer):
    return {"resourceType": "Parameters", "parameter": [{"name": "questionnaire_response", "resource": {
        "resourceType": "QuestionnaireResponse", "status": "completed", "questionnaire": "glucose",
        "subject": {"reference": f"Patient/{run.id(subject)}"},
        "item": [{"linkId": "patientId", "answer": [{"valueString": run.id(answer)}]},
                 {"linkId": "glucose-level", "answer": [{"valueDecimal": 5.5}]},
                 {"linkId": "dateTime", "answer": [{"valueDateTime": "2030-01-01T00:00:00Z"}]}]}}]}


def test_consented_practitioner_passes_the_gate(run, p1, p2):
    expect_allow(p1, "POST", POPULATE, json=populate(run, "patient-self"), send=False)
    expect_allow(p1, "POST", EXTRACT, json=extract(run, "patient-self", "patient-self"), send=False)
    expect_allow(p2, "POST", POPULATE, json=populate(run, "patient-other"), send=False)


@pytest.mark.parametrize("who", ["pat-self", "rec", "norole", "p2"])
def test_other_roles_denied(run, who):
    c = run.clients[who]
    expect_deny(c, "POST", POPULATE, json=populate(run, "patient-self"))
    expect_deny(c, "POST", EXTRACT, json=extract(run, "patient-self", "patient-self"))


def test_revoked_or_missing_consent_denied(run, p1):
    for patient in ("patient-other", "patient-unlinked"):
        expect_deny(p1, "POST", POPULATE, json=populate(run, patient))
        expect_deny(p1, "POST", EXTRACT, json=extract(run, patient, patient))


def test_forged_answer_denied(run, p1):
    # QR subject is a consented patient, but the hidden patientId answer points elsewhere
    expect_deny(p1, "POST", EXTRACT, json=extract(run, "patient-self", "patient-other"))
