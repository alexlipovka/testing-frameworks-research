"""Policy-decision assertions: a crashing policy and a plain deny both answer 403 otherwise."""

import json
from dataclasses import dataclass, replace
from typing import Any

import pytest
from fhirpy import AsyncFHIRClient
from fhirpy.base.exceptions import BaseFHIRError, ForbiddenError

from tests.raw_fhir import Body, execute_raw


@dataclass
class Decision:
    allowed_by: list[str]
    errors: list[dict[str, Any]]
    user: str | None

    @property
    def allowed(self) -> bool:
        return bool(self.allowed_by)

    def __str__(self) -> str:
        return f"user={self.user} allowed_by={self.allowed_by} errors={self.errors}"


@dataclass(frozen=True)
class Request:
    path: str
    method: str = "get"
    params: dict[str, Any] | None = None
    data: Body | None = None
    content_type: str | None = None

    def __str__(self) -> str:
        body = f" body={json.dumps(self.data)[:400]}" if self.data is not None else ""
        return f"{self.method.upper()} {self.path} params={self.params}{body}"


async def assert_allowed(
    client: AsyncFHIRClient,
    path: str,
    *,
    method: str = "get",
    params: dict[str, Any] | None = None,
    data: Body | None = None,
    content_type: str | None = None,
    by: str | None = None,
    send: bool = True,
) -> Any:
    request = Request(path, method, params, data, content_type)
    decision = await fetch_decision(client, request)
    assert decision.allowed and not decision.errors, f"expected allow for {request}: {decision}"
    if by:
        assert by in decision.allowed_by, f"expected allow by {by} for {request}: {decision}"
    if not send:
        return None
    try:
        return await send_request(client, request)
    except BaseFHIRError as error:
        pytest.fail(f"{request} failed after an allow decision: {error}; decision: {decision}")


async def assert_denied(
    client: AsyncFHIRClient,
    path: str,
    *,
    method: str = "get",
    params: dict[str, Any] | None = None,
    data: Body | None = None,
    content_type: str | None = None,
) -> None:
    request = Request(path, method, params, data, content_type)
    decision = await fetch_decision(client, request)
    assert not decision.allowed and not decision.errors, f"expected deny for {request}: {decision}"
    try:
        await send_request(client, request)
    except ForbiddenError:
        return
    except BaseFHIRError as error:
        pytest.fail(f"expected 403 for {request}, got: {error}; decision: {decision}")
    pytest.fail(f"expected 403 for {request}, but it succeeded; decision: {decision}")


async def fetch_decision(client: AsyncFHIRClient, request: Request) -> Decision:
    debug = replace(request, params={**(request.params or {}), "__debug": "policy"})
    return parse_decision(await send_request(client, debug))


def parse_decision(dump: dict[str, Any]) -> Decision:
    policies = dump.get("policies", [])
    return Decision(
        allowed_by=[p["id"] for p in policies if p.get("eval-result") is True],
        errors=[{"id": p["id"], "error": p["error"]} for p in policies if p.get("error")],
        user=(dump.get("request", {}).get("user") or {}).get("id"),
    )


async def send_request(client: AsyncFHIRClient, request: Request) -> Any:
    if request.content_type:
        return await execute_raw(
            client,
            request.method,
            request.path,
            content_type=request.content_type,
            data=request.data,
            params=request.params,
        )
    return await client.execute(
        request.path,
        method=request.method,
        data=request.data,  # type: ignore[arg-type]
        params=request.params,
    )
