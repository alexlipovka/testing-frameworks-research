from typing import Any

import fhirpy_types_r4b as r4b
from fhirpy.base.resource import serialize

V3_ACT_CODE = "http://terminology.hl7.org/CodeSystem/v3-ActCode"
V3_ROLE_CLASS = "http://terminology.hl7.org/CodeSystem/v3-RoleClass"
CONSENT_SCOPE = "http://terminology.hl7.org/CodeSystem/consentscope"


def build_patient(*, given: str = "Test", family: str = "Bakeoff") -> r4b.Patient:
    return r4b.Patient(name=[r4b.HumanName(given=[given], family=family)])


def build_practitioner() -> r4b.Practitioner:
    return r4b.Practitioner(name=[r4b.HumanName(given=["Test"], family="Bakeoff")])


def build_reference(resource: r4b.Patient | r4b.Practitioner) -> r4b.Reference:
    return r4b.Reference(reference=f"{resource.resourceType}/{resource.id}")


def build_encounter(*, subject: r4b.Reference) -> r4b.Encounter:
    return r4b.Encounter(
        status="finished",
        class_=r4b.Coding(system=V3_ACT_CODE, code="AMB"),
        subject=subject,
    )


def build_observation(*, subject: r4b.Reference) -> r4b.Observation:
    return r4b.Observation(
        status="final",
        code=r4b.CodeableConcept(text="Bakeoff weight"),
        subject=subject,
    )


def build_appointment(*, actor: r4b.Reference, status: str = "proposed") -> r4b.Appointment:
    return r4b.Appointment(
        status=status,
        participant=[r4b.AppointmentParticipant(actor=actor, status="needs-action")],
    )


def build_consent(
    *, patient: r4b.Reference, actor: r4b.Reference, status: str = "active"
) -> r4b.Consent:
    return r4b.Consent(
        status=status,
        scope=r4b.CodeableConcept(
            coding=[r4b.Coding(system=CONSENT_SCOPE, code="patient-privacy")]
        ),
        category=[
            r4b.CodeableConcept(coding=[r4b.Coding(system=V3_ACT_CODE, code="data-sharing")])
        ],
        patient=patient,
        policy=[r4b.ConsentPolicy(uri="https://beda.software/patient-consent")],
        provision=r4b.ConsentProvision(
            type="permit",
            actor=[
                r4b.ConsentProvisionActor(
                    role=r4b.CodeableConcept(
                        coding=[r4b.Coding(system=V3_ROLE_CLASS, code="PROV")]
                    ),
                    reference=actor,
                )
            ],
        ),
    )


def build_populate_parameters(*, subject: r4b.Reference) -> r4b.Parameters:
    return r4b.Parameters(
        parameter=[r4b.ParametersParameter(name="subject", valueReference=subject)]
    )


def build_extract_parameters(*, subject: r4b.Reference, answers: list[str]) -> r4b.Parameters:
    response = r4b.QuestionnaireResponse(
        status="completed",
        questionnaire="glucose",
        subject=subject,
        item=[
            r4b.QuestionnaireResponseItem(
                linkId="patientId",
                answer=[r4b.QuestionnaireResponseItemAnswer(valueString=id_) for id_ in answers],
            ),
            r4b.QuestionnaireResponseItem(
                linkId="glucose-level",
                answer=[r4b.QuestionnaireResponseItemAnswer(valueDecimal=5.5)],
            ),
            r4b.QuestionnaireResponseItem(
                linkId="dateTime",
                answer=[r4b.QuestionnaireResponseItemAnswer(valueDateTime="2030-01-01T00:00:00Z")],
            ),
        ],
    )
    return r4b.Parameters(
        parameter=[r4b.ParametersParameter(name="questionnaire_response", resource=response)]
    )


def dump_resource(resource: r4b.Parameters | r4b.Appointment) -> dict[str, Any]:
    return serialize(resource.model_dump())
