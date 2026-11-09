"""Case 9: $populate / $extract gated per role, forged answers and QR subject ownership.

Allowed calls assert only that the policy gate passed: the SUT lacks fhir-emr's launch context,
so the mapping output is not checked.
"""

from typing import Any

import fhirpy_types_r4b as r4b
import pytest
from fhirpy import AsyncFHIRClient

from tests.access_policy.conftest import save_consent
from tests.access_policy.decision import assert_allowed, assert_denied
from tests.fhir_resource_factories import (
    build_extract_parameters,
    build_populate_parameters,
    build_reference,
    dump_resource,
)

POPULATE = "Questionnaire/glucose/$populate"
EXTRACT = "Questionnaire/glucose/$extract"
SDC_POLICY = "as-practitioner-sdc-consented-patient"


def build_populate_body(patient: r4b.Patient) -> dict[str, Any]:
    return dump_resource(build_populate_parameters(subject=build_reference(patient)))


def build_extract_body(subject: r4b.Patient, *answers: r4b.Patient) -> dict[str, Any]:
    return dump_resource(
        build_extract_parameters(
            subject=build_reference(subject),
            answers=[str(answer.id) for answer in answers or (subject,)],
        )
    )


async def assert_sdc_denied(client: AsyncFHIRClient, patient: r4b.Patient) -> None:
    await assert_denied(client, POPULATE, method="post", data=build_populate_body(patient))
    await assert_denied(client, EXTRACT, method="post", data=build_extract_body(patient))


async def test_consented_practitioner_passes_the_gate(
    fhir_client: AsyncFHIRClient,
    practitioner_client: AsyncFHIRClient,
    other_practitioner_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    other_practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
    other_patient: r4b.Patient,
) -> None:
    await save_consent(fhir_client, own_patient, practitioner)
    await save_consent(fhir_client, other_patient, other_practitioner)

    await assert_allowed(
        practitioner_client,
        POPULATE,
        method="post",
        data=build_populate_body(own_patient),
        by=SDC_POLICY,
        send=False,
    )
    await assert_allowed(
        practitioner_client,
        EXTRACT,
        method="post",
        data=build_extract_body(own_patient),
        by=SDC_POLICY,
        send=False,
    )
    await assert_allowed(
        other_practitioner_client,
        POPULATE,
        method="post",
        data=build_populate_body(other_patient),
        by=SDC_POLICY,
        send=False,
    )


@pytest.mark.parametrize("who", ["patient", "receptionist", "norole"])
async def test_other_roles_denied(
    fhir_client: AsyncFHIRClient,
    patient_client: AsyncFHIRClient,
    receptionist_client: AsyncFHIRClient,
    norole_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
    who: str,
) -> None:
    # A Consent exists for the Patient: only the caller's role keeps them out.
    await save_consent(fhir_client, own_patient, practitioner)
    clients = {
        "patient": patient_client,
        "receptionist": receptionist_client,
        "norole": norole_client,
    }

    await assert_sdc_denied(clients[who], own_patient)


async def test_practitioner_without_consent_for_this_patient_denied(
    fhir_client: AsyncFHIRClient,
    other_practitioner_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    other_practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
    other_patient: r4b.Patient,
) -> None:
    await save_consent(fhir_client, own_patient, practitioner)
    await save_consent(fhir_client, other_patient, other_practitioner)

    await assert_sdc_denied(other_practitioner_client, own_patient)


async def test_revoked_consent_denied(
    fhir_client: AsyncFHIRClient,
    practitioner_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
    other_patient: r4b.Patient,
) -> None:
    await save_consent(fhir_client, own_patient, practitioner)
    await save_consent(fhir_client, other_patient, practitioner, status="inactive")

    await assert_sdc_denied(practitioner_client, other_patient)


async def test_missing_consent_denied(
    fhir_client: AsyncFHIRClient,
    practitioner_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
    other_patient: r4b.Patient,
) -> None:
    await save_consent(fhir_client, own_patient, practitioner)

    await assert_sdc_denied(practitioner_client, other_patient)


async def test_forged_answer_denied(
    fhir_client: AsyncFHIRClient,
    practitioner_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
    other_patient: r4b.Patient,
) -> None:
    # Both are consented: a policy that checks "the answer has a Consent" would pass the forgery.
    await save_consent(fhir_client, own_patient, practitioner)
    await save_consent(fhir_client, other_patient, practitioner)

    await assert_denied(
        practitioner_client,
        EXTRACT,
        method="post",
        data=build_extract_body(own_patient, other_patient),
    )


async def test_any_forged_answer_among_several_denied(
    fhir_client: AsyncFHIRClient,
    practitioner_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
    other_patient: r4b.Patient,
) -> None:
    await save_consent(fhir_client, own_patient, practitioner)

    await assert_denied(
        practitioner_client,
        EXTRACT,
        method="post",
        data=build_extract_body(own_patient, own_patient, other_patient),
    )


async def test_subject_without_consent_denied_even_with_a_consented_answer(
    fhir_client: AsyncFHIRClient,
    practitioner_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
    other_patient: r4b.Patient,
) -> None:
    await save_consent(fhir_client, own_patient, practitioner)

    await assert_denied(
        practitioner_client,
        EXTRACT,
        method="post",
        data=build_extract_body(other_patient, own_patient),
    )


async def test_two_populate_subjects_denied(
    fhir_client: AsyncFHIRClient,
    practitioner_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
    other_patient: r4b.Patient,
) -> None:
    await save_consent(fhir_client, own_patient, practitioner)
    body = build_populate_body(own_patient)
    body["parameter"] += build_populate_body(other_patient)["parameter"]

    await assert_denied(practitioner_client, POPULATE, method="post", data=body)
