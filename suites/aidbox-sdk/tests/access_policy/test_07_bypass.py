"""Case 7: writes and reads denied directly stay denied via Bundle, JSON Patch, merge-patch."""

import fhirpy_types_r4b as r4b
import pytest
from fhirpy import AsyncFHIRClient

from tests.access_policy.conftest import save_consent
from tests.access_policy.decision import assert_denied
from tests.fhir_resource_factories import build_appointment, build_reference, dump_resource
from tests.raw_fhir import JSON_PATCH, MERGE_PATCH

HACKED_PATCH = [{"op": "replace", "path": "/name/0/family", "value": "Hacked"}]
HACKED_MERGE = {"name": [{"family": "Hacked"}]}


async def assert_untouched(fhir_client: AsyncFHIRClient, patient: r4b.Patient) -> None:
    stored = await fhir_client.get(r4b.Patient, patient.id)
    assert stored.name and stored.name[0].family == "Bakeoff"


async def test_transaction_bundle_denied(
    fhir_client: AsyncFHIRClient,
    receptionist_client: AsyncFHIRClient,
    patient_client: AsyncFHIRClient,
    own_patient: r4b.Patient,
    other_patient: r4b.Patient,
) -> None:
    write = {
        "resourceType": "Bundle",
        "type": "transaction",
        "entry": [
            {
                "resource": {
                    "resourceType": "Patient",
                    "id": own_patient.id,
                    "name": [{"family": "Hacked"}],
                },
                "request": {"method": "PUT", "url": f"Patient/{own_patient.id}"},
            }
        ],
    }
    read = {
        "resourceType": "Bundle",
        "type": "batch",
        "entry": [{"request": {"method": "GET", "url": f"Patient/{other_patient.id}"}}],
    }

    await assert_denied(receptionist_client, "", method="post", data=write)
    await assert_denied(patient_client, "", method="post", data=read)
    await assert_untouched(fhir_client, own_patient)


async def test_bundles_are_denied_even_for_resources_the_role_may_touch(
    receptionist_client: AsyncFHIRClient,
    patient_client: AsyncFHIRClient,
    own_patient: r4b.Patient,
) -> None:
    appointment = dump_resource(build_appointment(actor=build_reference(own_patient)))
    create_appointment = {
        "resourceType": "Bundle",
        "type": "transaction",
        "entry": [{"resource": appointment, "request": {"method": "POST", "url": "Appointment"}}],
    }
    read_own = {
        "resourceType": "Bundle",
        "type": "batch",
        "entry": [{"request": {"method": "GET", "url": f"Patient/{own_patient.id}"}}],
    }

    await assert_denied(receptionist_client, "", method="post", data=create_appointment)
    await assert_denied(patient_client, "", method="post", data=read_own)


@pytest.mark.parametrize(
    "content_type, patch",
    [(JSON_PATCH, HACKED_PATCH), (MERGE_PATCH, HACKED_MERGE)],
    ids=["json-patch", "merge-patch"],
)
async def test_patch_denied(
    fhir_client: AsyncFHIRClient,
    receptionist_client: AsyncFHIRClient,
    practitioner_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
    content_type: str,
    patch: list | dict,
) -> None:
    # The Consent lets this practitioner read the Patient, so only the verb stands in the way.
    await save_consent(fhir_client, own_patient, practitioner)
    path = f"Patient/{own_patient.id}"

    await assert_denied(
        receptionist_client, path, method="patch", data=patch, content_type=content_type
    )
    await assert_denied(
        practitioner_client, path, method="patch", data=patch, content_type=content_type
    )
    await assert_untouched(fhir_client, own_patient)
