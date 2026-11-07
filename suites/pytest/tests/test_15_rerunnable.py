"""Case 15: the stamp/rollback teardown removes everything a run wrote, so the suite reruns cleanly.

Two full consecutive runs are `RUNS=2 ./run.sh`; this test checks the mechanism inside one run.
"""
from aidbox import psql


def test_rollback_to_stamp_removes_later_writes(run, admin):
    stamp = psql(admin, run.data["sql"]["stamp"])[0]["data"][0]["last_value"]
    pid = run.id("rerun")
    assert admin.put(f"/fhir/Patient/{pid}", json={"resourceType": "Patient", "id": pid}).status_code == 201
    psql(admin, run.data["sql"]["rollback"].replace("{{tx_id}}", str(stamp)))
    assert admin.get(f"/fhir/Patient/{pid}").status_code == 404
    assert admin.get(f"/fhir/Patient/{run.id('patient-self')}").status_code == 200
