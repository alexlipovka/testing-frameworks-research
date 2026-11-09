"""Case 8: 5 identities x 4 operations; each cell names the granting policy, or None for deny."""

from dataclasses import dataclass
from typing import Any

import fhirpy_types_r4b as r4b
import pytest
from fhirpy import AsyncFHIRClient

from tests.access_policy.conftest import SessionOpener, save_consent
from tests.access_policy.decision import assert_allowed, assert_denied
from tests.fhir_resource_factories import (
    build_appointment,
    build_encounter,
    build_patient,
    build_practitioner,
    build_reference,
    dump_resource,
)

MATRIX: dict[str, dict[str, str | None]] = {
    "patient": {
        "read-patient": "patient-role-policy",
        "search-patient": None,
        "read-encounter": "as-patient-read-own-encounter",
        "create-appointment": None,
    },
    "consented-practitioner": {
        "read-patient": "practitioner-policy",
        "search-patient": "as-practitioner-search-consented-patients",
        "read-encounter": None,
        "create-appointment": None,
    },
    "unconsented-practitioner": {
        "read-patient": None,
        "search-patient": None,
        "read-encounter": None,
        "create-appointment": None,
    },
    "receptionist": {
        "read-patient": "as-receptionist-read-patients",
        "search-patient": "as-receptionist-read-patients",
        "read-encounter": None,
        "create-appointment": "receptionist-role-policy",
    },
    "norole": {
        "read-patient": None,
        "search-patient": None,
        "read-encounter": None,
        "create-appointment": None,
    },
}
CELLS = [(who, op, policy) for who, row in MATRIX.items() for op, policy in row.items()]


@dataclass
class World:
    clients: dict[str, AsyncFHIRClient]
    patient: r4b.Patient
    encounter: r4b.Encounter


@pytest.fixture
async def world(fhir_client: AsyncFHIRClient, open_session: SessionOpener) -> World:
    patient = await fhir_client.save(build_patient())
    bystander = await fhir_client.save(build_patient())
    consented = await fhir_client.save(build_practitioner())
    unconsented = await fhir_client.save(build_practitioner())
    receptionist = await fhir_client.save(build_practitioner())
    encounter = await fhir_client.save(build_encounter(subject=build_reference(patient)))
    await fhir_client.save(build_encounter(subject=build_reference(bystander)))
    await save_consent(fhir_client, patient, consented)
    # The unconsented practitioner holds an active Consent, just not for this Patient.
    await save_consent(fhir_client, bystander, unconsented)
    return World(
        clients={
            "patient": await open_session("patient", patient=patient),
            "consented-practitioner": await open_session("practitioner", practitioner=consented),
            "unconsented-practitioner": await open_session(
                "practitioner", practitioner=unconsented
            ),
            "receptionist": await open_session("receptionist", practitioner=receptionist),
            "norole": await open_session(None),
        },
        patient=patient,
        encounter=encounter,
    )


@pytest.mark.parametrize("who, op, policy", CELLS, ids=[f"{who}-{op}" for who, op, _ in CELLS])
async def test_matrix(world: World, who: str, op: str, policy: str | None) -> None:
    path, request = build_operations(world)[op]

    if policy is None:
        await assert_denied(world.clients[who], path, **request)
    else:
        await assert_allowed(world.clients[who], path, by=policy, **request)


def build_operations(world: World) -> dict[str, tuple[str, dict[str, Any]]]:
    appointment = build_appointment(actor=build_reference(world.patient))
    return {
        "read-patient": (f"Patient/{world.patient.id}", {}),
        "search-patient": ("Patient", {"params": {"_id": world.patient.id}}),
        "read-encounter": (f"Encounter/{world.encounter.id}", {}),
        "create-appointment": (
            "Appointment",
            {"method": "post", "data": dump_resource(appointment)},
        ),
    }
