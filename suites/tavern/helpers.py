"""External functions the YAML tests call. conftest fills TOKENS."""

TOKENS: dict[str, str] = {}


def auth(who):
    """Authorization header for an identity name from fixtures.json, or admin."""
    return {"Authorization": TOKENS[who]}


def _policies(response):
    return response.json()["policies"]


def _granted(pols):
    return [p["policy-id"] for p in pols if p.get("eval-result") is True]


def _crashes(pols):
    return [{"id": p["policy-id"], "error": p["error"]} for p in pols if p.get("error")]


def _report(response):
    """Who asked for what, and how Aidbox decided: the text of every failed decision."""
    user = (response.json()["request"].get("user") or {}).get("id")
    pols = _policies(response)
    return f"user={user} {response.request.method} {response.request.url}: granted={_granted(pols)} crashed={_crashes(pols)}"


def decision(response, expect, policy=None):
    """Assert a __debug=policy dump: no policy crashed, and the request is allowed or denied."""
    pols = _policies(response)
    assert not _crashes(pols), f"expected {expect}, a policy crashed: {_report(response)}"
    granted = _granted(pols)
    if expect == "deny":
        assert not granted, f"expected deny: {_report(response)}"
    else:
        assert expect == "allow", f"expect must be allow or deny, got {expect!r}"
        assert granted, f"expected allow: {_report(response)}"
        assert not policy or policy in granted, f"expected allow by {policy}: {_report(response)}"


def crashed(response, policy):
    """Assert a __debug=policy dump shows `policy` crashed (an error, not a plain false) and nothing granted."""
    pols = {p["policy-id"]: p for p in _policies(response)}
    assert policy in pols, f"{policy} not evaluated; got {sorted(pols)}"
    assert pols[policy].get("error"), f"{policy} did not report an error: {pols[policy]}"
    granted = [k for k, p in pols.items() if p.get("eval-result") is True]
    assert not granted, f"granted by {granted}"


def bundle_ids(response, expected):
    """Assert a searchset holds exactly these `Type/id` entries."""
    got = sorted(f"{e['resource']['resourceType']}/{e['resource']['id']}" for e in response.json().get("entry", []))
    assert got == sorted(expected), f"bundle has {got}, expected {sorted(expected)}"


def sdc_body(op, subject, answer=None):
    """Parameters for Questionnaire/$populate or $extract about Patient/<subject>."""
    if op == "$populate":
        return {"resourceType": "Parameters", "parameter": [
            {"name": "subject", "valueReference": {"reference": f"Patient/{subject}"}},
            {"name": "LaunchPatient", "resource": {"resourceType": "Patient", "id": subject}}]}
    qr = {"resourceType": "QuestionnaireResponse", "questionnaire": "glucose", "status": "completed",
          "subject": {"reference": f"Patient/{subject}"},
          "item": [{"linkId": "patientId", "answer": [{"valueString": answer or subject}]}]}
    return {"resourceType": "Parameters", "parameter": [{"name": "questionnaire_response", "resource": qr}]}


def no_crash(response):
    assert not _crashes(_policies(response)), f"a policy crashed: {_report(response)}"


def tx_ids(response):
    """Save the ids a transaction created, from each entry's response.location."""
    loc = [e["response"]["location"].split("/_history")[0].split("/") for e in response.json()["entry"]]
    return {"patient_id": loc[0][-1], "obs_id": loc[1][-1]}
