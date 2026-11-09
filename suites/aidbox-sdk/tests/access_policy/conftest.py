"""Real password-grant sessions. Ids carry `bakeoff-` so the bench's residue check sees leaks."""

from collections.abc import Awaitable, Callable
from uuid import uuid4

import fhirpy_types_r4b as r4b
import pytest
from aidbox_python_sdk import app_keys as ak
from aidbox_python_sdk.aidboxpy import AsyncAidboxClient
from aiohttp import ClientSession, web
from fhirpy import AsyncFHIRClient

from tests.fhir_resource_factories import (
    build_consent,
    build_patient,
    build_practitioner,
    build_reference,
)

PASSWORD = "bakeoff-password"
CLIENT_SECRET = "bakeoff-client-secret"

SessionOpener = Callable[..., Awaitable[AsyncFHIRClient]]


@pytest.fixture
async def own_patient(fhir_client: AsyncFHIRClient) -> r4b.Patient:
    return await fhir_client.save(build_patient())


@pytest.fixture
async def other_patient(fhir_client: AsyncFHIRClient) -> r4b.Patient:
    return await fhir_client.save(build_patient())


@pytest.fixture
async def patient_client(open_session: SessionOpener, own_patient: r4b.Patient) -> AsyncFHIRClient:
    return await open_session("patient", patient=own_patient)


@pytest.fixture
async def practitioner(fhir_client: AsyncFHIRClient) -> r4b.Practitioner:
    return await fhir_client.save(build_practitioner())


@pytest.fixture
async def other_practitioner(fhir_client: AsyncFHIRClient) -> r4b.Practitioner:
    return await fhir_client.save(build_practitioner())


@pytest.fixture
async def practitioner_client(
    open_session: SessionOpener, practitioner: r4b.Practitioner
) -> AsyncFHIRClient:
    return await open_session("practitioner", practitioner=practitioner)


@pytest.fixture
async def other_practitioner_client(
    open_session: SessionOpener, other_practitioner: r4b.Practitioner
) -> AsyncFHIRClient:
    return await open_session("practitioner", practitioner=other_practitioner)


@pytest.fixture
async def receptionist_client(
    fhir_client: AsyncFHIRClient, open_session: SessionOpener
) -> AsyncFHIRClient:
    receptionist = await fhir_client.save(build_practitioner())
    return await open_session("receptionist", practitioner=receptionist)


@pytest.fixture
async def norole_client(open_session: SessionOpener) -> AsyncFHIRClient:
    return await open_session(None)


@pytest.fixture
def open_session(app: web.Application, aidbox_client: AsyncAidboxClient) -> SessionOpener:
    async def open_role_session(
        role_name: str | None, **links: r4b.Patient | r4b.Practitioner
    ) -> AsyncFHIRClient:
        session_id = f"bakeoff-{uuid4().hex[:8]}"
        await create_identity(aidbox_client, session_id, role_name, links)
        return await login(app, session_id)

    return open_role_session


async def save_consent(
    client: AsyncFHIRClient,
    patient: r4b.Patient,
    practitioner: r4b.Practitioner,
    status: str = "active",
) -> r4b.Consent:
    return await client.save(
        build_consent(
            patient=build_reference(patient),
            actor=build_reference(practitioner),
            status=status,
        )
    )


async def create_identity(
    client: AsyncAidboxClient, session_id: str, role_name: str | None, links: dict
) -> None:
    await client.execute(
        f"/Client/{session_id}",
        method="put",
        data={"secret": CLIENT_SECRET, "grant_types": ["password"], "first_party": True},
    )
    await client.execute(f"/User/{session_id}", method="put", data={"password": PASSWORD})
    if role_name is None:
        return
    await client.execute(
        f"/Role/{session_id}",
        method="put",
        data={
            "name": role_name,
            "user": {"id": session_id, "resourceType": "User"},
            **build_role_links(links),
        },
    )


def build_role_links(links: dict) -> dict:
    """Aidbox rejects an empty `links` object, so a role without links omits the key."""
    if not links:
        return {}
    return {
        "links": {
            name: {"id": resource.id, "resourceType": resource.resourceType}
            for name, resource in links.items()
        }
    }


async def login(app: web.Application, session_id: str) -> AsyncFHIRClient:
    settings = app[ak.settings]
    async with ClientSession() as session:
        response = await session.post(
            f"{settings.APP_INIT_URL}/auth/token",
            json={
                "grant_type": "password",
                "client_id": session_id,
                "client_secret": CLIENT_SECRET,
                "username": session_id,
                "password": PASSWORD,
            },
        )
        token = (await response.json())["access_token"]
    return AsyncFHIRClient(
        f"{settings.APP_INIT_URL}/fhir",
        authorization=f"Bearer {token}",
        dump_resource=lambda x: x.model_dump(),
    )
