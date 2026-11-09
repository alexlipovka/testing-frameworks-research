"""Case 13: transaction Bundles resolve urn:uuid references and are all-or-nothing."""

import re
from uuid import uuid4

import fhirpy_types_r4b as r4b
from fhirpy import AsyncFHIRClient

from tests.raw_fhir import request_raw


async def test_urn_references_resolved(fhir_client: AsyncFHIRClient) -> None:
    urn = f"urn:uuid:{uuid4()}"
    bundle = {
        "resourceType": "Bundle",
        "type": "transaction",
        "entry": [
            {
                "fullUrl": urn,
                "resource": {"resourceType": "Patient", "name": [{"family": "Tx"}]},
                "request": {"method": "POST", "url": "Patient"},
            },
            {
                "resource": {
                    "resourceType": "Observation",
                    "status": "final",
                    "code": {"text": "Tx"},
                    "subject": {"reference": urn},
                },
                "request": {"method": "POST", "url": "Observation"},
            },
        ],
    }

    response = await fhir_client.execute("", method="post", data=bundle)

    assert response["type"] == "transaction-response"
    assert [entry["response"]["status"][:3] for entry in response["entry"]] == ["201", "201"]
    patient_ref, observation_ref = (
        parse_location(entry["response"]["location"]) for entry in response["entry"]
    )
    observation = await fhir_client.get(r4b.Observation, observation_ref.split("/")[1])
    assert observation.subject and observation.subject.reference == patient_ref


async def test_failed_entry_rolls_back_whole_bundle(fhir_client: AsyncFHIRClient) -> None:
    family = f"Tx{uuid4().hex[:8]}"
    bundle = {
        "resourceType": "Bundle",
        "type": "transaction",
        "entry": [
            {
                "resource": {"resourceType": "Patient", "name": [{"family": family}]},
                "request": {"method": "POST", "url": "Patient"},
            },
            {
                "resource": {"resourceType": "Patient", "birthDate": "not-a-date"},
                "request": {"method": "POST", "url": "Patient"},
            },
        ],
    }

    status, outcome = await request_raw(fhir_client, "post", "", data=bundle)

    assert 400 <= status < 500, outcome
    survivors = await fhir_client.execute("Patient", method="get", params={"family": family})
    assert not survivors.get("entry")


def parse_location(location: str) -> str:
    """`http://host/fhir/Observation/<id>/_history/<v>` -> `Observation/<id>`"""
    match = re.search(r"/fhir/(\w+/[^/]+)/_history/", location)
    assert match, location
    return match.group(1)
