import signal

import pytest
from aidbox_python_sdk import app_keys as ak
from aiohttp import encode_basic_auth, web
from fhirpy import AsyncFHIRClient

from tests import run_stamp

pytest_plugins = ["aidbox_python_sdk.pytest_plugin"]

RUN_OPENED = pytest.StashKey[bool]()
INTERRUPTED = pytest.StashKey[bool]()


def pytest_configure(config: pytest.Config) -> None:
    # Python as PID 1 ignores SIGTERM, and `docker stop` would then skip the rollback.
    signal.signal(signal.SIGTERM, lambda *_: stop_run(config))
    run_stamp.open_run()
    config.stash[RUN_OPENED] = True


def pytest_unconfigure(config: pytest.Config) -> None:
    if config.stash.get(RUN_OPENED, False):
        run_stamp.close_run(settle=config.stash.get(INTERRUPTED, False))


def stop_run(config: pytest.Config) -> None:
    config.stash[INTERRUPTED] = True
    raise KeyboardInterrupt


@pytest.fixture
def fhir_client(app: web.Application) -> AsyncFHIRClient:
    settings = app[ak.settings]
    return AsyncFHIRClient(
        f"{settings.APP_INIT_URL}/fhir",
        authorization=encode_basic_auth(
            str(settings.APP_INIT_CLIENT_ID), str(settings.APP_INIT_CLIENT_SECRET)
        ),
        dump_resource=lambda x: x.model_dump(),
    )
