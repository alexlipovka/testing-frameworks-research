"""fhirpy's `execute` cannot set headers and r4b models reject invalid resources; these can."""

import json
from typing import Any
from urllib.parse import urlencode

from aiohttp import ClientSession
from fhirpy import AsyncFHIRClient
from fhirpy.base.exceptions import ForbiddenError, OperationOutcome
from yarl import URL

FHIR_JSON = "application/fhir+json"
JSON_PATCH = "application/json-patch+json"
MERGE_PATCH = "application/merge-patch+json"

Body = dict[str, Any] | list[dict[str, Any]]


async def execute_raw(
    client: AsyncFHIRClient,
    method: str,
    path: str,
    *,
    content_type: str = FHIR_JSON,
    data: Body | None = None,
    params: dict[str, Any] | None = None,
) -> Any:
    status, payload = await request_raw(
        client, method, path, content_type=content_type, data=data, params=params
    )
    if status == 403:
        raise ForbiddenError(json.dumps(payload))
    if not 200 <= status < 300:
        raise OperationOutcome(reason=f"{status} {json.dumps(payload)}")
    return payload


async def request_raw(
    client: AsyncFHIRClient,
    method: str,
    path: str,
    *,
    content_type: str = FHIR_JSON,
    data: Body | None = None,
    params: dict[str, Any] | None = None,
) -> tuple[int, Any]:
    headers = {"Authorization": str(client.authorization), "Content-Type": content_type}
    body = None if data is None else json.dumps(data)
    async with ClientSession(headers=headers) as session:
        async with session.request(method, build_url(client, path, params), data=body) as response:
            text = await response.text()
            return response.status, json.loads(text) if text else None


def build_url(client: AsyncFHIRClient, path: str, params: dict[str, Any] | None) -> URL:
    # encoded=True keeps a %5F in `path` as sent: yarl would otherwise normalise it to `_`.
    query = urlencode(params, doseq=True, safe=":,/") if params else ""
    separator = "&" if "?" in path else "?"
    suffix = f"{separator}{query}" if query else ""
    return URL(f"{client.url.rstrip('/')}/{path.lstrip('/')}{suffix}", encoded=True)
