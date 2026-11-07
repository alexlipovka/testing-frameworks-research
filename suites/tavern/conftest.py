"""Fixture contract from sut/fixtures/README.md. The tx stamp is saved before the
first write, so a session killed before its teardown is rolled back at the next start."""

import base64
import json
import os
import secrets
import signal
from pathlib import Path

import pytest
import requests

import helpers

BASE = os.environ.get("AIDBOX_URL", "http://localhost:8280")
ADMIN = ("root", "secret")
FIXTURES = Path(os.environ.get("FIXTURES_JSON", "/fixtures/fixtures.json"))
STATE = Path(__file__).parent / ".run" / "state.json"
RUN_ID = f"bakeoff-{secrets.token_hex(4)}"


def load(run_id):
    return json.loads(FIXTURES.read_text().replace("{{run_id}}", run_id))


def sql(query):
    r = requests.post(f"{BASE}/$psql", json={"query": query}, auth=ADMIN, timeout=30)
    r.raise_for_status()
    out = r.json()
    assert out["status"] == "success", out
    return out


def rollback(tx_id):
    sql(json.loads(FIXTURES.read_text())["sql"]["rollback"].replace("{{tx_id}}", str(tx_id)))
    STATE.unlink(missing_ok=True)


def recover():
    if STATE.exists():
        rollback(json.loads(STATE.read_text())["tx_id"])


def pytest_configure(config):
    # Tavern formats parametrize values at collection, before any fixture runs,
    # so run_id must reach it through a global config file.
    cfg = STATE.parent / "global.yaml"
    cfg.parent.mkdir(exist_ok=True)
    cfg.write_text(json.dumps({"variables": {"run_id": RUN_ID, "base": BASE}}))
    config.option.tavern_global_cfg = [*(config.option.tavern_global_cfg or []), str(cfg)]


def _sigterm(*_):
    raise KeyboardInterrupt


@pytest.fixture(scope="session", autouse=True)
def run():
    # Python as PID 1 ignores SIGTERM; docker stop would skip the teardown.
    signal.signal(signal.SIGTERM, _sigterm)
    recover()
    data = load(RUN_ID)
    sql(data["sql"]["install"])
    tx_id = sql(data["sql"]["stamp"])["result"][0]["data"][0]["last_value"]
    STATE.write_text(json.dumps({"run_id": RUN_ID, "tx_id": tx_id}))
    try:
        for s in data["setup"]:
            r = requests.request(s["method"], BASE + s["path"], json=s["body"], auth=ADMIN, timeout=30)
            assert r.ok, f"setup {s['path']}: {r.status_code} {r.text}"
        sec = data["secrets"]
        tokens = {"admin": "Basic " + base64.b64encode(":".join(ADMIN).encode()).decode()}
        for i in data["identities"]:
            r = requests.post(f"{BASE}/auth/token", timeout=30, json={
                "grant_type": "password", "client_id": sec["client_id"], "client_secret": sec["client_secret"],
                "username": i["user"], "password": sec["user_password"]})
            assert r.ok, f"token {i['name']}: {r.status_code} {r.text}"
            tokens[i["name"]] = "Bearer " + r.json()["access_token"]
        helpers.TOKENS.update(tokens)
        yield {f"{k.replace('-', '_')}_auth": v for k, v in tokens.items()}
    finally:
        rollback(tx_id)


def pytest_tavern_beta_before_every_test_run(test_dict, variables):
    variables.update(variables["run"])
