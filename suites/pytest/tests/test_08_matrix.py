"""Case 8: 5 identities x 4 operations; every cell asserts the policy decision and the status."""
import pytest

from aidbox import expect_allow, expect_deny

OPS = ["read_patient", "search_patient", "read_encounter", "create_appointment"]
MATRIX = """
            read_patient  search_patient  read_encounter  create_appointment
pat-self    allow         deny            allow           deny
p1          allow         allow           deny            deny
p2          deny          deny            deny            deny
rec         allow         allow           deny            allow
norole      deny          deny            deny            deny
"""
CELLS = [(row[0], op, d) for row in (l.split() for l in MATRIX.strip().splitlines()[1:])
         for op, d in zip(OPS, row[1:])]


def request(run, op):
    pid = run.id("patient-self")
    return {
        "read_patient": ("GET", f"/fhir/Patient/{pid}", {}),
        "search_patient": ("GET", f"/fhir/Patient?_id={pid}", {}),
        "read_encounter": ("GET", f"/fhir/Encounter/{run.id('enc-match')}", {}),
        "create_appointment": ("POST", "/fhir/Appointment", {"json": {
            "resourceType": "Appointment", "status": "proposed",
            "participant": [{"actor": {"reference": f"Patient/{pid}"}, "status": "needs-action"}]}}),
    }[op]


@pytest.mark.parametrize("who, op, decision", CELLS, ids=[f"{w}-{o}" for w, o, _ in CELLS])
def test_matrix(run, who, op, decision):
    method, url, kw = request(run, op)
    (expect_allow if decision == "allow" else expect_deny)(run.clients[who], method, url, **kw)
