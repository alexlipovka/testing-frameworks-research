"""Case 12: search with _include, _revinclude and chaining."""

from typing import Any
from uuid import uuid4

from fhirpy import AsyncFHIRClient

from tests.fhir_resource_factories import (
    build_encounter,
    build_observation,
    build_patient,
    build_reference,
)


async def test_include(fhir_client: AsyncFHIRClient) -> None:
    patient = await fhir_client.save(build_patient())
    encounter = await fhir_client.save(build_encounter(subject=build_reference(patient)))

    bundle = await fhir_client.execute(
        "Encounter",
        method="get",
        params={"_id": encounter.id, "_include": "Encounter:subject"},
    )

    assert collect_search_modes(bundle) == {
        f"Encounter/{encounter.id}": "match",
        f"Patient/{patient.id}": "include",
    }


async def test_revinclude(fhir_client: AsyncFHIRClient) -> None:
    patient = await fhir_client.save(build_patient())
    observation = await fhir_client.save(build_observation(subject=build_reference(patient)))

    bundle = await fhir_client.execute(
        "Patient",
        method="get",
        params={"_id": patient.id, "_revinclude": "Observation:subject"},
    )

    assert collect_search_modes(bundle) == {
        f"Patient/{patient.id}": "match",
        f"Observation/{observation.id}": "include",
    }


async def test_chaining(fhir_client: AsyncFHIRClient) -> None:
    given = f"Chain{uuid4().hex[:8]}"
    patient = await fhir_client.save(build_patient(given=given))
    bystander = await fhir_client.save(build_patient())
    encounter = await fhir_client.save(build_encounter(subject=build_reference(patient)))
    other_encounter = await fhir_client.save(build_encounter(subject=build_reference(bystander)))

    bundle = await fhir_client.execute(
        "Encounter", method="get", params={"subject:Patient.given": given}
    )

    found = collect_search_modes(bundle)
    assert f"Encounter/{encounter.id}" in found
    assert f"Encounter/{other_encounter.id}" not in found


def collect_search_modes(bundle: dict[str, Any]) -> dict[str, str | None]:
    return {
        f"{entry['resource']['resourceType']}/{entry['resource']['id']}": entry.get(
            "search", {}
        ).get("mode")
        for entry in bundle.get("entry", [])
    }
