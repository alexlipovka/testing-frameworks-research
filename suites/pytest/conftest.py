import pytest

from aidbox import Run


@pytest.fixture(scope="session")
def run():
    r = Run.open()
    try:
        # Stamp before the first write, so a setup that fails halfway is still torn down
        r.stamp()
        r.setup()
        yield r
    finally:
        r.teardown()


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
