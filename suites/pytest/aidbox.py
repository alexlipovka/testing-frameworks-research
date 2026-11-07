"""Shared fixture contract (sut/fixtures/README.md) and policy-decision assertions."""
import json
import os
import secrets
from dataclasses import dataclass, field

import httpx

AIDBOX_URL = os.environ.get("AIDBOX_URL", "http://localhost:8280")
FIXTURES = os.environ.get("FIXTURES_JSON", "/fixtures.json")
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

    def id(self, name: str) -> str:
        return f"{self.run_id}-{name}"

    @classmethod
    def open(cls) -> "Run":
        run_id = f"bakeoff-{secrets.token_hex(4)}"
        with open(FIXTURES) as f:
            data = json.loads(f.read().replace("{{run_id}}", run_id))
        return cls(run_id, data, client(auth=ADMIN))

    def stamp(self):
        psql(self.admin, self.data["sql"]["install"])
        self.tx_id = psql(self.admin, self.data["sql"]["stamp"])[0]["data"][0]["last_value"]

    def setup(self):
        for req in self.data["setup"]:
            r = self.admin.request(req["method"], req["path"], json=req["body"])
            assert r.is_success, f"setup {req['path']}: {r.status_code} {r.text}"
        s = self.data["secrets"]
        for ident in self.data["identities"]:
            self.clients[ident["name"]] = login(ident["user"], s)

    def teardown(self):
        for c in self.clients.values():
            c.close()
        if self.tx_id is not None:
            psql(self.admin, self.data["sql"]["rollback"].replace("{{tx_id}}", str(self.tx_id)))
        self.admin.close()


def login(user: str, s: dict) -> httpx.Client:
    r = httpx.post(f"{AIDBOX_URL}/auth/token", json={
        "grant_type": "password", "client_id": s["client_id"], "client_secret": s["client_secret"],
        "username": user, "password": s["user_password"]})
    assert r.is_success, f"token for {user}: {r.status_code} {r.text}"
    return client(headers={"Authorization": f"Bearer {r.json()['access_token']}"})


@dataclass
class Verdict:
    allowed_by: list[str]
    errors: list[dict]
    dump: dict

    @property
    def allowed(self) -> bool:
        return bool(self.allowed_by)

    def __str__(self):
        return f"allowed_by={self.allowed_by} errors={self.errors}"


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
    assert r.status_code != 403 and r.is_success, f"{method} {url}: {r.status_code} {r.text[:500]}"
    return r


def expect_deny(c, method, url, **kw):
    """No policy allows and none errored (an error is not a deny); the real call is 403."""
    v = verdict(c, method, url, **kw)
    assert not v.allowed and not v.errors, f"expected deny for {method} {url}: {v}"
    r = c.request(method, url, **kw)
    assert r.status_code == 403, f"{method} {url}: {r.status_code} {r.text[:500]}"
    return r
