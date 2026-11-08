"""Case 8: 5 identities x 4 operations; each cell names the granting policy, or - for deny."""
import pytest

from aidbox import expect_allow, expect_deny

OPS = ["read_patient", "search_patient", "read_encounter", "create_appointment"]
MATRIX = """
            read_patient                   search_patient                             read_encounter                 create_appointment
pat-self    patient-role-policy            -                                          as-patient-read-own-encounter  -
p1          practitioner-policy            as-practitioner-search-consented-patients  -                              -
p2          -                              -                                          -                              -
rec         as-receptionist-read-patients  as-receptionist-read-patients              -                              receptionist-role-policy
norole      -                              -                                          -                              -
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


@pytest.mark.parametrize("who, op, policy", CELLS, ids=[f"{w}-{o}" for w, o, _ in CELLS])
def test_matrix(run, who, op, policy):
    method, url, kw = request(run, op)
    if policy == "-":
        expect_deny(run.clients[who], method, url, **kw)
    else:
        expect_allow(run.clients[who], method, url, by=policy, **kw)
