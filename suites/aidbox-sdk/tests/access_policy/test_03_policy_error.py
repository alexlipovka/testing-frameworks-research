"""Case 3: a SQL policy that throws shows up as an error in the decision, not as a plain deny."""

from typing import Any
from uuid import uuid4

import fhirpy_types_r4b as r4b
import pytest
from aidbox_python_sdk.aidboxpy import AsyncAidboxClient
from fhirpy import AsyncFHIRClient
from fhirpy.base.exceptions import ForbiddenError

from tests.access_policy.conftest import SessionOpener, save_consent
from tests.access_policy.decision import Request, assert_allowed, fetch_decision
from tests.fhir_resource_factories import build_encounter, build_observation, build_reference

THROWING_SQL = {"engine": "sql", "sql": {"query": "SELECT 1/0 = 1"}}


@pytest.mark.parametrize(
    "policy",
    [THROWING_SQL, {"engine": "complex", "and": [THROWING_SQL]}],
    ids=["sql", "sql-nested-in-complex"],
)
async def test_throwing_sql_policy_is_an_error(
    aidbox_client: AsyncAidboxClient,
    open_session: SessionOpener,
    own_patient: r4b.Patient,
    policy: dict[str, Any],
) -> None:
    role_name = f"bakeoff-thrower-{uuid4().hex[:8]}"
    policy_id = f"{role_name}-policy"
    thrower = await open_session(role_name)
    await aidbox_client.execute(
        f"/AccessPolicy/{policy_id}", method="put", data={"roleName": role_name, **policy}
    )
    path = f"Patient/{own_patient.id}"

    try:
        decision = await fetch_decision(thrower, Request(path))

        assert not decision.allowed
        assert [error["id"] for error in decision.errors] == [policy_id], str(decision)
        with pytest.raises(ForbiddenError):
            await thrower.execute(path, method="get")
    finally:
        await aidbox_client.execute(f"/AccessPolicy/{policy_id}", method="delete")


async def test_baseline_policies_do_not_throw_on_patient_requests(
    fhir_client: AsyncFHIRClient, patient_client: AsyncFHIRClient, own_patient: r4b.Patient
) -> None:
    reference = build_reference(own_patient)
    encounter = await fhir_client.save(build_encounter(subject=reference))
    await fhir_client.save(build_observation(subject=reference))

    await assert_allowed(patient_client, f"Patient/{own_patient.id}")
    await assert_allowed(patient_client, f"Encounter/{encounter.id}")
    await assert_allowed(patient_client, "Observation", params={"subject": reference.reference})


async def test_baseline_policies_do_not_throw_on_staff_requests(
    fhir_client: AsyncFHIRClient,
    practitioner_client: AsyncFHIRClient,
    receptionist_client: AsyncFHIRClient,
    practitioner: r4b.Practitioner,
    own_patient: r4b.Patient,
) -> None:
    await save_consent(fhir_client, own_patient, practitioner)

    await assert_allowed(practitioner_client, f"Patient/{own_patient.id}")
    await assert_allowed(practitioner_client, "Patient", params={"_id": own_patient.id})
    await assert_allowed(receptionist_client, f"Patient/{own_patient.id}")
    await assert_allowed(receptionist_client, "Appointment")
