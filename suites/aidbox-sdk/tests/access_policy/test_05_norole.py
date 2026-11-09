"""Case 5: an identity with no role is denied everywhere."""

from dataclasses import dataclass
from typing import Any

import fhirpy_types_r4b as r4b
import pytest
from fhirpy import AsyncFHIRClient

from tests.access_policy.decision import assert_denied
from tests.fhir_resource_factories import (
    build_appointment,
    build_encounter,
    build_observation,
    build_populate_parameters,
    build_reference,
    dump_resource,
)

REQUEST_NAMES = [
    "read-patient",
    "search-patient",
    "read-encounter",
    "search-observation",
    "read-appointment",
    "update-patient",
    "create-appointment",
    "populate",
    "transaction",
]


@dataclass
class ClinicalData:
    patient: r4b.Patient
    encounter: r4b.Encounter
    appointment: r4b.Appointment


@pytest.fixture
async def clinical_data(fhir_client: AsyncFHIRClient, own_patient: r4b.Patient) -> ClinicalData:
    reference = build_reference(own_patient)
    await fhir_client.save(build_observation(subject=reference))
    return ClinicalData(
        patient=own_patient,
        encounter=await fhir_client.save(build_encounter(subject=reference)),
        appointment=await fhir_client.save(build_appointment(actor=reference)),
    )


@pytest.mark.parametrize("name", REQUEST_NAMES)
async def test_norole_denied(
    norole_client: AsyncFHIRClient, clinical_data: ClinicalData, name: str
) -> None:
    path, request = build_requests(clinical_data)[name]

    await assert_denied(norole_client, path, **request)


def build_requests(data: ClinicalData) -> dict[str, tuple[str, dict[str, Any]]]:
    patient_id = data.patient.id
    reference = build_reference(data.patient)
    appointment = dump_resource(build_appointment(actor=reference))
    transaction = {
        "resourceType": "Bundle",
        "type": "transaction",
        "entry": [{"request": {"method": "GET", "url": f"Patient/{patient_id}"}}],
    }
    return {
        "read-patient": (f"Patient/{patient_id}", {}),
        "search-patient": ("Patient", {"params": {"_id": patient_id}}),
        "read-encounter": (f"Encounter/{data.encounter.id}", {}),
        "search-observation": ("Observation", {"params": {"subject": reference.reference}}),
        "read-appointment": (f"Appointment/{data.appointment.id}", {}),
        "update-patient": (
            f"Patient/{patient_id}",
            {"method": "put", "data": {"resourceType": "Patient", "id": patient_id}},
        ),
        "create-appointment": ("Appointment", {"method": "post", "data": appointment}),
        "populate": (
            "Questionnaire/glucose/$populate",
            {
                "method": "post",
                "data": dump_resource(build_populate_parameters(subject=reference)),
            },
        ),
        "transaction": ("", {"method": "post", "data": transaction}),
    }
