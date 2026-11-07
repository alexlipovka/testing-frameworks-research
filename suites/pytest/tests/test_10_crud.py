"""Case 10: CRUD + JSON Patch as admin."""
import json


def test_crud_and_json_patch(run, admin):
    pid = run.id("crud")
    url = f"/fhir/Patient/{pid}"
    r = admin.put(url, json={"resourceType": "Patient", "id": pid, "name": [{"family": "Crud"}]})
    assert r.status_code == 201, r.text
    v1 = r.json()["meta"]["versionId"]

    assert admin.get(url).json()["name"] == [{"family": "Crud"}]

    r = admin.put(url, json={"resourceType": "Patient", "id": pid, "name": [{"family": "Crud2"}]})
    assert r.status_code == 200, r.text
    assert r.json()["meta"]["versionId"] != v1

    r = admin.patch(url, headers={"Content-Type": "application/json-patch+json"}, content=json.dumps([
        {"op": "replace", "path": "/name/0/family", "value": "Patched"},
        {"op": "add", "path": "/birthDate", "value": "2000-01-01"}]))
    assert r.status_code == 200, r.text
    got = admin.get(url).json()
    assert got["name"][0]["family"] == "Patched" and got["birthDate"] == "2000-01-01"

    assert admin.delete(url).status_code in (200, 204)
    assert admin.get(url).status_code in (404, 410)


def test_create_with_server_id(admin):
    r = admin.post("/fhir/Patient", json={"resourceType": "Patient", "name": [{"family": "Posted"}]})
    assert r.status_code == 201, r.text
    assert admin.get(f"/fhir/Patient/{r.json()['id']}").json()["name"][0]["family"] == "Posted"
