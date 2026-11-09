"""Case 4: a receptionist reads Patients but cannot write them, and manages Appointments."""

from typing import Any

import fhirpy_types_r4b as r4b
import pytest
from fhirpy import AsyncFHIRClient

from tests.access_policy.decision import assert_allowed, assert_denied
from tests.fhir_resource_factories import (
    build_appointment,
    build_encounter,
    build_observation,
    build_reference,
    dump_resource,
)
from tests.raw_fhir import JSON_PATCH, MERGE_PATCH

READ_PATIENTS = "as-receptionist-read-patients"
MANAGE_APPOINTMENTS = "receptionist-role-policy"
HACKED_PATIENT = {"resourceType": "Patient", "name": [{"family": "Hacked"}]}
HACKED_PATCH = [{"op": "replace", "path": "/name/0/family", "value": "Hacked"}]

WRITES: dict[str, dict[str, Any]] = {
    "put": {"method": "put", "data": HACKED_PATIENT},
    "json-patch": {"method": "patch", "data": HACKED_PATCH, "content_type": JSON_PATCH},
    "merge-patch": {"method": "patch", "data": HACKED_PATIENT, "content_type": MERGE_PATCH},
    "delete": {"method": "delete"},
}


async def test_receptionist_reads_patients(
    receptionist_client: AsyncFHIRClient, own_patient: r4b.Patient, other_patient: r4b.Patient
) -> None:
    patient = await assert_allowed(
        receptionist_client, f"Patient/{own_patient.id}", by=READ_PATIENTS
    )
    assert patient["id"] == own_patient.id

    bundle = await assert_allowed(
        receptionist_client, "Patient", params={"_id": other_patient.id}, by=READ_PATIENTS
    )
    assert [entry["resource"]["id"] for entry in bundle["entry"]] == [other_patient.id]


@pytest.mark.parametrize("write", list(WRITES))
async def test_receptionist_cannot_write_patients(
    fhir_client: AsyncFHIRClient,
    receptionist_client: AsyncFHIRClient,
    own_patient: r4b.Patient,
    write: str,
) -> None:
    await assert_denied(receptionist_client, f"Patient/{own_patient.id}", **WRITES[write])

    stored = await fhir_client.get(r4b.Patient, own_patient.id)
    assert stored.name and stored.name[0].family == "Bakeoff"


async def test_receptionist_cannot_create_patients(receptionist_client: AsyncFHIRClient) -> None:
    await assert_denied(receptionist_client, "Patient", method="post", data=HACKED_PATIENT)


async def test_receptionist_manages_appointments(
    receptionist_client: AsyncFHIRClient, own_patient: r4b.Patient
) -> None:
    body = dump_resource(build_appointment(actor=build_reference(own_patient)))

    created = await assert_allowed(
        receptionist_client, "Appointment", method="post", data=body, by=MANAGE_APPOINTMENTS
    )
    path = f"Appointment/{created['id']}"
    await assert_allowed(receptionist_client, path, by=MANAGE_APPOINTMENTS)
    bundle = await assert_allowed(
        receptionist_client, "Appointment", params={"_id": created["id"]}, by=MANAGE_APPOINTMENTS
    )
    assert [entry["resource"]["id"] for entry in bundle["entry"]] == [created["id"]]
    await assert_allowed(
        receptionist_client,
        path,
        method="put",
        data={**body, "status": "cancelled"},
        by=MANAGE_APPOINTMENTS,
    )
    await assert_allowed(
        receptionist_client,
        path,
        method="patch",
        data=[{"op": "add", "path": "/comment", "value": "rescheduled"}],
        content_type=JSON_PATCH,
        by=MANAGE_APPOINTMENTS,
    )
    await assert_allowed(receptionist_client, path, method="delete", by=MANAGE_APPOINTMENTS)


async def test_receptionist_sees_nothing_clinical(
    fhir_client: AsyncFHIRClient, receptionist_client: AsyncFHIRClient, own_patient: r4b.Patient
) -> None:
    reference = build_reference(own_patient)
    encounter = await fhir_client.save(build_encounter(subject=reference))
    observation = await fhir_client.save(build_observation(subject=reference))

    await assert_denied(receptionist_client, f"Encounter/{encounter.id}")
    await assert_denied(receptionist_client, f"Observation/{observation.id}")
    await assert_denied(receptionist_client, "Observation", params={"_id": observation.id})
