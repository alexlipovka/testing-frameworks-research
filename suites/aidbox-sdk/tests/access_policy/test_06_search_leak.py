"""Case 6: allowed searches return nothing outside scope; out-of-scope searches are denied."""

from typing import Any

import fhirpy_types_r4b as r4b
import pytest
from fhirpy import AsyncFHIRClient

from tests.access_policy.conftest import save_consent
from tests.access_policy.decision import assert_allowed, assert_denied, parse_decision
from tests.fhir_resource_factories import build_appointment, build_observation, build_reference
from tests.raw_fhir import request_raw


def collect_ids(bundle: dict[str, Any]) -> set[str]:
    return {
        f"{entry['resource']['resourceType']}/{entry['resource']['id']}"
        for entry in bundle.get("entry", [])
    }


@pytest.fixture
async def own_observation(
    fhir_client: AsyncFHIRClient, own_patient: r4b.Patient
) -> r4b.Observation:
    return await fhir_client.save(build_observation(subject=build_reference(own_patient)))


@pytest.fixture
async def other_observation(
    fhir_client: AsyncFHIRClient, other_patient: r4b.Patient
) -> r4b.Observation:
    return await fhir_client.save(build_observation(subject=build_reference(other_patient)))


@pytest.mark.parametrize("subject_form", ["Patient/{id}", "{id}"])
async def test_patient_searches_only_own_observations(
    patient_client: AsyncFHIRClient,
    own_patient: r4b.Patient,
    own_observation: r4b.Observation,
    other_observation: r4b.Observation,
    subject_form: str,
) -> None:
    bundle = await assert_allowed(
        patient_client,
        "Observation",
        params={"subject": subject_form.format(id=own_patient.id)},
    )

    assert collect_ids(bundle) == {f"Observation/{own_observation.id}"}


async def test_patient_out_of_scope_searches_denied(
    patient_client: AsyncFHIRClient,
    own_patient: r4b.Patient,
    other_patient: r4b.Patient,
    own_observation: r4b.Observation,
    other_observation: r4b.Observation,
) -> None:
    own = f"Patient/{own_patient.id}"
    other = f"Patient/{other_patient.id}"

    await assert_denied(patient_client, "Observation", params={"subject": other})
    await assert_denied(patient_client, "Observation")
    await assert_denied(patient_client, "Observation", params={"subject": [own, other]})
    await assert_denied(patient_client, "Observation", params={"subject": f"{own},{other}"})
    await assert_denied(
        patient_client, "Observation", params={"subject": own, "_include": "Observation:subject"}
    )
    await assert_denied(
        patient_client,
        "Observation",
        params={"subject": own, "_revinclude": "Provenance:target"},
    )


async def test_practitioner_searches_only_consented_patients(
    fhir_client: AsyncFHIRClient,
    practitioner_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    other_practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
    other_patient: r4b.Patient,
) -> None:
    await save_consent(fhir_client, own_patient, practitioner)
    await save_consent(fhir_client, other_patient, other_practitioner)

    bundle = await assert_allowed(practitioner_client, "Patient", params={"_id": own_patient.id})
    assert collect_ids(bundle) == {f"Patient/{own_patient.id}"}

    await assert_denied(
        practitioner_client, "Patient", params={"_id": f"{own_patient.id},{other_patient.id}"}
    )
    await assert_denied(practitioner_client, "Patient")
    await assert_denied(practitioner_client, "Patient", params={"_id": other_patient.id})
    await assert_denied(practitioner_client, "Observation", params={"_id": own_patient.id})
    await assert_denied(
        practitioner_client,
        "Patient",
        params={"_id": own_patient.id, "_include": "Patient:general-practitioner"},
    )
    await assert_denied(
        practitioner_client,
        "Patient",
        params={"_id": own_patient.id, "_revinclude": "Observation:subject"},
    )


async def test_practitioner_revoked_consent_does_not_count_in_search(
    fhir_client: AsyncFHIRClient,
    practitioner_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
    other_patient: r4b.Patient,
) -> None:
    await save_consent(fhir_client, own_patient, practitioner)
    await save_consent(fhir_client, other_patient, practitioner, status="inactive")

    await assert_denied(
        practitioner_client, "Patient", params={"_id": f"{own_patient.id},{other_patient.id}"}
    )


async def test_receptionist_search_has_no_includes(
    fhir_client: AsyncFHIRClient,
    receptionist_client: AsyncFHIRClient,
    own_patient: r4b.Patient,
    own_observation: r4b.Observation,
) -> None:
    appointment = await fhir_client.save(build_appointment(actor=build_reference(own_patient)))

    bundle = await assert_allowed(receptionist_client, "Patient", params={"_id": own_patient.id})
    assert collect_ids(bundle) == {f"Patient/{own_patient.id}"}

    await assert_denied(
        receptionist_client,
        "Patient",
        params={"_id": own_patient.id, "_revinclude": "Observation:subject"},
    )
    await assert_denied(
        receptionist_client,
        "Patient",
        params={"_id": own_patient.id, "_revinclude:iterate": "Observation:subject"},
    )
    await assert_denied(
        receptionist_client,
        "Appointment",
        params={"_id": appointment.id, "_include": "Appointment:actor"},
    )


async def test_receptionist_percent_encoded_include_is_denied(
    receptionist_client: AsyncFHIRClient,
    own_patient: r4b.Patient,
    own_observation: r4b.Observation,
) -> None:
    path = f"Patient?_id={own_patient.id}&%5Frevinclude=Observation:subject"

    status, dump = await request_raw(receptionist_client, "get", path, params={"__debug": "policy"})
    decision = parse_decision(dump)
    assert status == 200 and not decision.allowed and not decision.errors, f"{path}: {decision}"

    status, _ = await request_raw(receptionist_client, "get", path)
    assert status == 403, f"{path}: {status}; decision: {decision}"
