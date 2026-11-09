"""Case 10: CRUD, JSON Patch and merge-patch as admin."""

from uuid import uuid4

import fhirpy_types_r4b as r4b
import pytest
from fhirpy import AsyncFHIRClient
from fhirpy.base.exceptions import ResourceNotFound

from tests.fhir_resource_factories import build_patient
from tests.raw_fhir import JSON_PATCH, MERGE_PATCH, execute_raw, request_raw


async def test_create_with_server_id(fhir_client: AsyncFHIRClient) -> None:
    created = await fhir_client.save(build_patient(family="Posted"))

    assert created.id
    stored = await fhir_client.get(r4b.Patient, created.id)
    assert stored.name and stored.name[0].family == "Posted"


async def test_put_to_a_fresh_id_creates_then_updates(fhir_client: AsyncFHIRClient) -> None:
    # The client-chosen id is the behaviour under test: PUT upserts, 201 first and 200 after.
    path = f"Patient/{uuid4()}"
    body = {"resourceType": "Patient", "name": [{"family": "Crud"}]}

    status, created = await request_raw(fhir_client, "put", path, data=body)
    assert status == 201, created

    status, updated = await request_raw(
        fhir_client, "put", path, data={**body, "name": [{"family": "Crud2"}]}
    )
    assert status == 200, updated
    assert updated["meta"]["versionId"] != created["meta"]["versionId"]


async def test_update_patch_delete(fhir_client: AsyncFHIRClient) -> None:
    patient = await fhir_client.save(build_patient(family="Crud"))
    assert patient.name
    patient.name[0].family = "Crud2"
    updated = await fhir_client.save(patient)
    assert updated.name and updated.name[0].family == "Crud2"

    await execute_raw(
        fhir_client,
        "patch",
        f"Patient/{updated.id}",
        content_type=JSON_PATCH,
        data=[
            {"op": "replace", "path": "/name/0/family", "value": "Patched"},
            {"op": "add", "path": "/birthDate", "value": "2000-01-01"},
        ],
    )

    stored = await fhir_client.get(r4b.Patient, updated.id)
    assert stored.name and stored.name[0].family == "Patched"
    assert stored.birthDate == "2000-01-01"

    await fhir_client.delete(r4b.Patient, updated.id)
    with pytest.raises(ResourceNotFound):
        await fhir_client.get(r4b.Patient, updated.id)


async def test_merge_patch_replaces_only_named_fields(fhir_client: AsyncFHIRClient) -> None:
    patient = await fhir_client.save(build_patient(family="Merge"))

    await execute_raw(
        fhir_client,
        "patch",
        f"Patient/{patient.id}",
        content_type=MERGE_PATCH,
        data={"birthDate": "1999-12-31"},
    )

    stored = await fhir_client.get(r4b.Patient, patient.id)
    assert stored.birthDate == "1999-12-31"
    assert stored.name and stored.name[0].family == "Merge"
