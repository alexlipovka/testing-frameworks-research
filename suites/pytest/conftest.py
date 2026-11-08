import signal

import pytest

from aidbox import Run


def _interrupt(*_):
    raise KeyboardInterrupt


def pytest_configure(config):
    if hasattr(config, "workerinput"):
        config.bakeoff_run = Run.attach(config.workerinput["bakeoff_run"])
    else:
        # Python as PID 1 ignores SIGTERM, and `docker stop` would then skip the teardown.
        signal.signal(signal.SIGTERM, _interrupt)
        config.bakeoff_run = Run.start()


@pytest.hookimpl(optionalhook=True)
def pytest_configure_node(node):
    # One run for the whole session: a session fixture would open one per xdist worker.
    node.workerinput["bakeoff_run"] = node.config.bakeoff_run.state()


def pytest_unconfigure(config):
    run = getattr(config, "bakeoff_run", None)
    if run:
        run.close() if hasattr(config, "workerinput") else run.teardown()


@pytest.fixture(scope="session")
def run(pytestconfig):
    return pytestconfig.bakeoff_run


@pytest.fixture(scope="session")
def admin(run):
    return run.admin


@pytest.fixture(scope="session")
def pat_self(run):
    return run.clients["pat-self"]


@pytest.fixture(scope="session")
def p1(run):
    return run.clients["p1"]


@pytest.fixture(scope="session")
def p2(run):
    return run.clients["p2"]


@pytest.fixture(scope="session")
def rec(run):
    return run.clients["rec"]


@pytest.fixture(scope="session")
def norole(run):
    return run.clients["norole"]
