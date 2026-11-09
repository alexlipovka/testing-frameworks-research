"""Case 1: a patient reads their own Patient (matcho policy), not someone else's."""

import fhirpy_types_r4b as r4b
from fhirpy import AsyncFHIRClient

from tests.access_policy.decision import assert_allowed, assert_denied
from tests.fhir_resource_factories import build_encounter, build_reference
from tests.raw_fhir import JSON_PATCH


async def test_patient_reads_own_record(
    patient_client: AsyncFHIRClient, own_patient: r4b.Patient
) -> None:
    await assert_allowed(patient_client, f"Patient/{own_patient.id}", by="patient-role-policy")

    patient = await patient_client.get(r4b.Patient, own_patient.id)

    assert patient.id == own_patient.id


async def test_patient_cannot_read_other_record(
    patient_client: AsyncFHIRClient, other_patient: r4b.Patient
) -> None:
    await assert_denied(patient_client, f"Patient/{other_patient.id}")


async def test_patient_reads_own_encounter(
    fhir_client: AsyncFHIRClient, patient_client: AsyncFHIRClient, own_patient: r4b.Patient
) -> None:
    encounter = await fhir_client.save(build_encounter(subject=build_reference(own_patient)))

    await assert_allowed(
        patient_client, f"Encounter/{encounter.id}", by="as-patient-read-own-encounter"
    )

    assert (await patient_client.get(r4b.Encounter, encounter.id)).id == encounter.id


async def test_patient_cannot_read_other_encounter(
    fhir_client: AsyncFHIRClient,
    patient_client: AsyncFHIRClient,
    own_patient: r4b.Patient,
    other_patient: r4b.Patient,
) -> None:
    # Without an Encounter of their own, a policy matching "any of my Encounters" still denies.
    await fhir_client.save(build_encounter(subject=build_reference(own_patient)))
    encounter = await fhir_client.save(build_encounter(subject=build_reference(other_patient)))

    await assert_denied(patient_client, f"Encounter/{encounter.id}")


async def test_encounter_id_under_wrong_type_is_denied(
    fhir_client: AsyncFHIRClient, patient_client: AsyncFHIRClient, own_patient: r4b.Patient
) -> None:
    encounter = await fhir_client.save(build_encounter(subject=build_reference(own_patient)))

    await assert_denied(patient_client, f"Observation/{encounter.id}")


async def test_own_patient_id_under_wrong_type_is_denied(
    patient_client: AsyncFHIRClient, own_patient: r4b.Patient
) -> None:
    await assert_denied(patient_client, f"Observation/{own_patient.id}")


async def test_patient_cannot_search_encounters(
    fhir_client: AsyncFHIRClient, patient_client: AsyncFHIRClient, own_patient: r4b.Patient
) -> None:
    await fhir_client.save(build_encounter(subject=build_reference(own_patient)))

    await assert_denied(
        patient_client, "Encounter", params={"subject": f"Patient/{own_patient.id}"}
    )


async def test_patient_cannot_write_own_record(
    fhir_client: AsyncFHIRClient, patient_client: AsyncFHIRClient, own_patient: r4b.Patient
) -> None:
    path = f"Patient/{own_patient.id}"
    renamed = {"resourceType": "Patient", "name": [{"family": "Hacked"}]}
    patch = [{"op": "replace", "path": "/name/0/family", "value": "Hacked"}]

    await assert_denied(patient_client, path, method="put", data=renamed)
    await assert_denied(patient_client, path, method="patch", data=patch, content_type=JSON_PATCH)
    await assert_denied(patient_client, path, method="delete")

    stored = await fhir_client.get(r4b.Patient, own_patient.id)
    assert stored.name and stored.name[0].family == "Bakeoff"
