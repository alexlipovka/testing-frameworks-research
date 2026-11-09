"""Case 14: rows of earlier tests and other runs are gone, and look-alikes are out of reach."""

import fhirpy_types_r4b as r4b
from fhirpy import AsyncFHIRClient

from tests.access_policy.decision import assert_denied
from tests.fhir_resource_factories import build_patient


async def test_only_this_test_patients_exist(
    fhir_client: AsyncFHIRClient, own_patient: r4b.Patient, other_patient: r4b.Patient
) -> None:
    bundle = await fhir_client.execute(
        "Patient", method="get", params={"family:exact": "Bakeoff", "_count": 100}
    )

    assert {entry["resource"]["id"] for entry in bundle.get("entry", [])} == {
        own_patient.id,
        other_patient.id,
    }


async def test_identical_looking_patient_is_denied(
    fhir_client: AsyncFHIRClient, patient_client: AsyncFHIRClient, own_patient: r4b.Patient
) -> None:
    twin = await fhir_client.save(build_patient())

    await assert_denied(patient_client, f"Patient/{twin.id}")
