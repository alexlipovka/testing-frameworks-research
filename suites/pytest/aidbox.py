"""Shared fixture contract (sut/fixtures/README.md) and policy-decision assertions."""
import json
import os
import secrets
import time
from dataclasses import dataclass, field

import httpx

AIDBOX_URL = os.environ.get("AIDBOX_URL", "http://localhost:8280")
FIXTURES = os.environ.get("FIXTURES_JSON", "/fixtures.json")
OPEN_RUN = "reports/open-run.json"
interrupted = False
ADMIN = ("root", "secret")


def client(**kw) -> httpx.Client:
    return httpx.Client(base_url=AIDBOX_URL, timeout=30, **kw)


def psql(admin: httpx.Client, query: str) -> list:
    r = admin.post("/$psql", json={"query": query})
    r.raise_for_status()
    out = r.json()
    assert out["status"] == "success", out
    return out["result"]


@dataclass
class Run:
    run_id: str
    data: dict
    admin: httpx.Client
    tx_id: int | None = None
    clients: dict[str, httpx.Client] = field(default_factory=dict)
    tokens: dict[str, str] = field(default_factory=dict)

    def id(self, name: str) -> str:
        return f"{self.run_id}-{name}"

    @classmethod
    def start(cls) -> "Run":
        """Open a run: stamp before the first write, so a setup that fails halfway is still torn down."""
        if os.path.exists(OPEN_RUN):
            raise RuntimeError(f"a run is open ({OPEN_RUN}): ./run.sh teardown first")
        run_id = f"bakeoff-{secrets.token_hex(4)}"
        run = cls(run_id, load_fixtures(run_id), client(auth=ADMIN))
        try:
            run.stamp()
            run.setup()
        except BaseException:
            run.teardown()
            raise
        return run

    @classmethod
    def attach(cls, state: dict) -> "Run":
        """The run as an xdist worker sees it: opened by the controller, closed by it too."""
        run = cls(state["run_id"], load_fixtures(state["run_id"]), client(auth=ADMIN), state["tx_id"])
        run.tokens = state["tokens"]
        run.clients = {who: bearer(token) for who, token in run.tokens.items()}
        return run

    def state(self) -> dict:
        return {"run_id": self.run_id, "tx_id": self.tx_id, "tokens": self.tokens}

    def stamp(self):
        psql(self.admin, self.data["sql"]["install"])
        self.tx_id = psql(self.admin, self.data["sql"]["stamp"])[0]["data"][0]["last_value"]
        with open(OPEN_RUN, "w") as f:
            json.dump({"run_id": self.run_id, "tx_id": self.tx_id}, f)

    def setup(self):
        for req in self.data["setup"]:
            r = self.admin.request(req["method"], req["path"], json=req["body"])
            assert r.is_success, f"setup {req['path']}: {r.status_code} {r.text}"
        s = self.data["secrets"]
        for ident in self.data["identities"]:
            self.tokens[ident["name"]] = token_for(ident["user"], s)
            self.clients[ident["name"]] = bearer(self.tokens[ident["name"]])

    def close(self):
        for c in self.clients.values():
            c.close()
        self.admin.close()

    def teardown(self):
        if self.tx_id is not None:
            # A request the interrupt cut off can still commit on the server; rolling back first would miss it.
            if interrupted:
                time.sleep(1)
            psql(self.admin, self.data["sql"]["rollback"].replace("{{tx_id}}", str(self.tx_id)))
            os.remove(OPEN_RUN)
        self.close()


def load_fixtures(run_id: str) -> dict:
    with open(FIXTURES) as f:
        return json.loads(f.read().replace("{{run_id}}", run_id))


def close_open_run():
    """Roll back a run left behind by a killed runner."""
    if not os.path.exists(OPEN_RUN):
        return
    with open(OPEN_RUN) as f:
        tx_id = json.load(f)["tx_id"]
    with client(auth=ADMIN) as admin:
        psql(admin, load_fixtures("")["sql"]["rollback"].replace("{{tx_id}}", str(tx_id)))
    os.remove(OPEN_RUN)


def token_for(user: str, s: dict) -> str:
    r = httpx.post(f"{AIDBOX_URL}/auth/token", json={
        "grant_type": "password", "client_id": s["client_id"], "client_secret": s["client_secret"],
        "username": user, "password": s["user_password"]})
    assert r.is_success, f"token for {user}: {r.status_code} {r.text}"
    return r.json()["access_token"]


def bearer(token: str) -> httpx.Client:
    return client(headers={"Authorization": f"Bearer {token}"})


def login(user: str, s: dict) -> httpx.Client:
    return bearer(token_for(user, s))


@dataclass
class Verdict:
    allowed_by: list[str]
    errors: list[dict]
    dump: dict

    @property
    def allowed(self) -> bool:
        return bool(self.allowed_by)

    def __str__(self):
        user = (self.dump.get("request", {}).get("user") or {}).get("id")
        return f"user={user} allowed_by={self.allowed_by} errors={self.errors}"


def verdict(c: httpx.Client, method: str, url: str, **kw) -> Verdict:
    """Ask Aidbox how it would decide this request (`__debug=policy`) without enforcing it."""
    sep = "&" if "?" in url else "?"
    r = c.request(method, f"{url}{sep}__debug=policy", **kw)
    assert r.status_code == 200, f"debug {method} {url}: {r.status_code} {r.text[:500]}"
    dump = r.json()
    policies = dump.get("policies", [])
    return Verdict(
        allowed_by=[p["id"] for p in policies if p.get("eval-result") is True],
        errors=[{"id": p["id"], "error": p["error"]} for p in policies if p.get("error")],
        dump=dump,
    )


def expect_allow(c, method, url, *, by: str | None = None, send: bool = True, **kw):
    """Policy decision is allow (optionally by policy `by`) with no policy error; then the real call succeeds."""
    v = verdict(c, method, url, **kw)
    assert v.allowed and not v.errors, f"expected allow for {method} {url}: {v}"
    if by:
        assert by in v.allowed_by, f"expected allow by {by} for {method} {url}: {v}"
    if not send:
        return v
    r = c.request(method, url, **kw)
    assert r.status_code != 403 and r.is_success, f"{method} {url}: {r.status_code} {r.text[:500]}; decision: {v}"
    return r


def expect_deny(c, method, url, **kw):
    """No policy allows and none errored (an error is not a deny); the real call is 403."""
    v = verdict(c, method, url, **kw)
    assert not v.allowed and not v.errors, f"expected deny for {method} {url}: {v}"
    r = c.request(method, url, **kw)
    assert r.status_code == 403, f"{method} {url}: {r.status_code} {r.text[:500]}; decision: {v}"
    return r
