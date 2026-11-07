"""External functions the YAML tests call. conftest fills TOKENS."""

TOKENS: dict[str, str] = {}


def auth(who):
    """Authorization header for an identity name from fixtures.json, or admin."""
    return {"Authorization": TOKENS[who]}


def _policies(response):
    return response.json()["policies"]


def decision(response, expect, policy=None):
    """Assert a __debug=policy dump: no policy crashed, and the request is allowed or denied."""
    pols = _policies(response)
    crashed = [p["policy-id"] for p in pols if p.get("error")]
    assert not crashed, f"policies crashed: {crashed}"
    granted = [p["policy-id"] for p in pols if p.get("eval-result") is True]
    if expect == "deny":
        assert not granted, f"expected deny, granted by {granted}"
    else:
        assert expect == "allow", f"expect must be allow or deny, got {expect!r}"
        assert granted, "expected allow, no policy granted"
        assert policy is None or policy in granted, f"expected {policy}, granted by {granted}"


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
    crashed = [p["policy-id"] for p in _policies(response) if p.get("error")]
    assert not crashed, f"policies crashed: {crashed}"


def tx_ids(response):
    """Save the ids a transaction created, from each entry's response.location."""
    loc = [e["response"]["location"].split("/_history")[0].split("/") for e in response.json()["entry"]]
    return {"patient_id": loc[0][-1], "obs_id": loc[1][-1]}
