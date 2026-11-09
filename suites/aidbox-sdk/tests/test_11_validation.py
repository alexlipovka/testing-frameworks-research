"""Case 11: an invalid resource is rejected with an OperationOutcome."""

from typing import Any

import pytest
from fhirpy import AsyncFHIRClient

from tests.raw_fhir import request_raw


@pytest.mark.parametrize(
    "body",
    [
        {"resourceType": "Patient", "birthDate": "not-a-date"},
        {"resourceType": "Patient", "unknownElement": 1},
    ],
    ids=["bad-date", "unknown-element"],
)
async def test_invalid_patient_rejected(fhir_client: AsyncFHIRClient, body: dict[str, Any]) -> None:
    status, outcome = await request_raw(fhir_client, "post", "Patient", data=body)

    assert status == 422, outcome
    assert outcome["resourceType"] == "OperationOutcome"
    assert outcome["issue"]
    assert all(issue["severity"] in ("error", "fatal") for issue in outcome["issue"])
