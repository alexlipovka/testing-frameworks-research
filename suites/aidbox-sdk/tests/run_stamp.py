"""Session-level rollback point, kept on disk so that a killed run can still be closed.

safe_db's stamp is per test and in memory, and the App registers before the first test.
"""

import asyncio
import json
import time
from pathlib import Path
from typing import Any

import pytest
from aidbox_python_sdk.db import parse_psql_response
from aidbox_python_sdk.db_migrations import sdk_migrations
from aidbox_python_sdk.settings import Settings
from aiohttp import ClientSession, encode_basic_auth

OPEN_RUN = Path("reports/open-run.json")
# A request the interrupt cut off can still commit on the server after the rollback.
SETTLE_SECONDS = 1


def open_run() -> None:
    if OPEN_RUN.exists():
        raise pytest.UsageError(f"a run is open ({OPEN_RUN}): ./run.sh teardown first")
    OPEN_RUN.write_text(json.dumps({"tx_id": asyncio.run(fetch_stamp())}))


def close_run(*, settle: bool = False) -> None:
    if settle:
        time.sleep(SETTLE_SECONDS)
    tx_id = json.loads(OPEN_RUN.read_text())["tx_id"]
    asyncio.run(roll_back(tx_id))
    OPEN_RUN.unlink()


def close_left_open_run() -> None:
    if not OPEN_RUN.exists():
        print("no open run")
        return
    close_run(settle=True)
    print("open run closed")


async def fetch_stamp() -> int:
    settings = Settings()
    async with open_admin_session(settings) as session:
        # A run killed before the App's migrations ran must still find the rollback function.
        await run_psql(session, settings, sdk_migrations[-1]["sql"])
        rows = await run_psql(session, settings, "SELECT last_value FROM transaction_id_seq")
    return int(rows[0][0]["last_value"])


async def roll_back(tx_id: int) -> None:
    settings = Settings()
    async with open_admin_session(settings) as session:
        # Over REST so Aidbox handles the unregistration itself: the rollback only removes rows.
        async with session.delete(f"{settings.APP_INIT_URL}/App/{settings.APP_ID}") as response:
            if response.status not in (200, 204, 404, 410):
                raise RuntimeError(f"DELETE App: {response.status} {await response.text()}")
        await run_psql(session, settings, f"SELECT drop_before_all({tx_id})")


def open_admin_session(settings: Settings) -> ClientSession:
    authorization = encode_basic_auth(
        str(settings.APP_INIT_CLIENT_ID), str(settings.APP_INIT_CLIENT_SECRET)
    )
    return ClientSession(headers={"Authorization": authorization})


async def run_psql(session: ClientSession, settings: Settings, query: str) -> list[Any]:
    url = f"{settings.APP_INIT_URL}/$psql"
    async with session.post(url, params={"execute": "true"}, json={"query": query}) as response:
        response.raise_for_status()
        return parse_psql_response(await response.json())


if __name__ == "__main__":
    close_left_open_run()
