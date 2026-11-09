"""Case 2: a practitioner reads a Patient through an active Consent; a revoked one denies."""

import fhirpy_types_r4b as r4b
import pytest
from fhirpy import AsyncFHIRClient

from tests.access_policy.conftest import save_consent
from tests.access_policy.decision import assert_allowed, assert_denied
from tests.fhir_resource_factories import build_consent, build_reference


async def test_active_consent_allows(
    fhir_client: AsyncFHIRClient,
    practitioner_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
) -> None:
    await save_consent(fhir_client, own_patient, practitioner)

    await assert_allowed(practitioner_client, f"Patient/{own_patient.id}", by="practitioner-policy")

    assert (await practitioner_client.get(r4b.Patient, own_patient.id)).id == own_patient.id


async def test_each_practitioner_uses_their_own_consent(
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

    await assert_allowed(practitioner_client, f"Patient/{own_patient.id}", by="practitioner-policy")
    await assert_allowed(
        other_practitioner_client, f"Patient/{other_patient.id}", by="practitioner-policy"
    )


async def test_practitioner_named_as_a_later_actor_is_allowed(
    fhir_client: AsyncFHIRClient,
    practitioner_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    other_practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
) -> None:
    consent = build_consent(
        patient=build_reference(own_patient), actor=build_reference(other_practitioner)
    )
    assert consent.provision and consent.provision.actor
    consent.provision.actor.append(
        r4b.ConsentProvisionActor(
            role=consent.provision.actor[0].role, reference=build_reference(practitioner)
        )
    )
    await fhir_client.save(consent)

    await assert_allowed(practitioner_client, f"Patient/{own_patient.id}", by="practitioner-policy")


async def test_consented_patient_id_under_wrong_type_is_denied(
    fhir_client: AsyncFHIRClient,
    practitioner_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
) -> None:
    await save_consent(fhir_client, own_patient, practitioner)

    await assert_denied(practitioner_client, f"Encounter/{own_patient.id}")


@pytest.mark.parametrize("status", ["inactive", "draft"])
async def test_revoked_consent_denies(
    fhir_client: AsyncFHIRClient,
    practitioner_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    other_practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
    other_patient: r4b.Patient,
    status: str,
) -> None:
    await save_consent(fhir_client, own_patient, practitioner, status=status)
    # A broken join would pass on these: my active Consent elsewhere, an active one by someone else.
    await save_consent(fhir_client, other_patient, practitioner)
    await save_consent(fhir_client, own_patient, other_practitioner)

    await assert_denied(practitioner_client, f"Patient/{own_patient.id}")


async def test_no_consent_denies(
    fhir_client: AsyncFHIRClient,
    practitioner_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    other_practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
    other_patient: r4b.Patient,
) -> None:
    await save_consent(fhir_client, other_patient, practitioner)
    await save_consent(fhir_client, own_patient, other_practitioner)

    await assert_denied(practitioner_client, f"Patient/{own_patient.id}")


async def test_consent_of_another_practitioner_denies(
    fhir_client: AsyncFHIRClient,
    other_practitioner_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    other_practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
    other_patient: r4b.Patient,
) -> None:
    await save_consent(fhir_client, own_patient, practitioner)
    await save_consent(fhir_client, other_patient, other_practitioner)

    await assert_denied(other_practitioner_client, f"Patient/{own_patient.id}")
