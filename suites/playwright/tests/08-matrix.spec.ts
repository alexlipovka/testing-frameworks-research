import { test, type Identity, type Req } from '../lib/test';

type Op = 'read' | 'search' | 'update' | 'create-appointment';
const ops: Record<Op, (id: (f: string) => string) => Req> = {
  read: (id) => ({ path: `/fhir/Patient/${id('patient-self')}` }),
  search: (id) => ({ path: `/fhir/Patient?_id=${id('patient-self')}` }),
  update: (id) => ({
    method: 'PUT',
    path: `/fhir/Patient/${id('patient-self')}`,
    data: { resourceType: 'Patient', id: id('patient-self'), name: [{ given: ['Self'], family: 'Bakeoff' }] },
  }),
  'create-appointment': (id) => ({
    method: 'POST',
    path: '/fhir/Appointment',
    data: {
      resourceType: 'Appointment',
      status: 'proposed',
      participant: [{ actor: { reference: `Patient/${id('patient-self')}` }, status: 'needs-action' }],
    },
  }),
};

// The granting policy, or null for deny
const matrix: Record<Identity, Record<Op, string | null>> = {
  'pat-self': { read: 'patient-role-policy', search: null, update: null, 'create-appointment': null },
  p1: { read: 'practitioner-policy', search: 'as-practitioner-search-consented-patients', update: null, 'create-appointment': null },
  p2: { read: null, search: null, update: null, 'create-appointment': null },
  rec: { read: 'as-receptionist-read-patients', search: 'as-receptionist-read-patients', update: null, 'create-appointment': 'receptionist-role-policy' },
  norole: { read: null, search: null, update: null, 'create-appointment': null },
};

test.describe('8. matrix: 5 identities × 4 operations on patient-self', () => {
  for (const [who, row] of Object.entries(matrix) as [Identity, Record<Op, string | null>][]) {
    for (const [op, policy] of Object.entries(row) as [Op, string | null][]) {
      test(`${who} ${op}: ${policy ? `allow via ${policy}` : 'deny'}`, async ({ run, allows, denies }) => {
        const req = ops[op](run.id);
        if (policy) await allows(who, req, policy);
        else await denies(who, req);
      });
    }
  }
});
