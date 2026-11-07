"""Case 3: a SQL policy that throws shows up as an error in the decision, not as a plain deny."""
from aidbox import expect_allow, login, verdict


def test_throwing_sql_policy_is_an_error(run, admin):
    user = run.id("thrower")
    assert admin.put(f"/User/{user}", json={"resourceType": "User", "id": user,
                                             "password": run.data["secrets"]["user_password"]}).is_success
    # Scoped by a run-unique role: a `link` to User/<id> reports "no links" for a password-grant session
    assert admin.put(f"/Role/{user}-role", json={"resourceType": "Role", "name": user,
                                                 "user": {"resourceType": "User", "id": user}}).is_success
    policy = run.id("throwing-policy")
    r = admin.put(f"/AccessPolicy/{policy}", json={
        "resourceType": "AccessPolicy", "id": policy, "engine": "sql", "roleName": user,
        "sql": {"query": "SELECT 1/0 = 1"}})
    assert r.is_success, r.text
    try:
        with login(user, run.data["secrets"]) as thrower:
            url = f"/fhir/Patient/{run.id('patient-self')}"
            v = verdict(thrower, "GET", url)
            assert not v.allowed
            assert [e["id"] for e in v.errors] == [policy], v
            # Without the debug dump the crash is indistinguishable from a deny
            assert thrower.get(url).status_code == 403
    finally:
        admin.delete(f"/AccessPolicy/{policy}")


def test_baseline_policies_do_not_throw_on_patient_requests(run, pat_self):
    for url in (f"/fhir/Patient/{run.id('patient-self')}",
                f"/fhir/Encounter/{run.id('enc-match')}",
                f"/fhir/Observation?subject=Patient/{run.id('patient-self')}"):
        expect_allow(pat_self, "GET", url, send=False)
