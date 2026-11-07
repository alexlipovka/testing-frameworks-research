import { test, expect } from '../lib/test';

test.describe('13. transaction Bundle semantics', () => {
  test('entries commit together and urn:uuid references are resolved', async ({ run, admin }) => {
    const res = await admin.post('/fhir', {
      data: {
        resourceType: 'Bundle',
        type: 'transaction',
        entry: [
          {
            fullUrl: 'urn:uuid:11111111-1111-4111-8111-111111111111',
            resource: { resourceType: 'Patient', name: [{ family: run.runId, given: ['Tx'] }] },
            request: { method: 'POST', url: 'Patient' },
          },
          {
            resource: {
              resourceType: 'Observation',
              status: 'final',
              code: { text: 'Tx weight' },
              subject: { reference: 'urn:uuid:11111111-1111-4111-8111-111111111111' },
            },
            request: { method: 'POST', url: 'Observation' },
          },
        ],
      },
    });
    expect(res.status(), await res.text()).toBe(200);
    const out = await res.json();
    expect(out.type).toBe('transaction-response');
    expect(out.entry).toHaveLength(2);
    // Aidbox answers with an absolute versioned URL: <base>/fhir/Patient/<id>/_history/<vid>
    const [patientId, obsId] = out.entry.map((e: any) => {
      const m = /\/(Patient|Observation)\/([^/]+)\/_history\//.exec(e.response.location);
      expect(m, e.response.location).not.toBeNull();
      return m![2];
    });
    const obs = await (await admin.get(`/fhir/Observation/${obsId}`)).json();
    expect(obs.subject.reference).toBe(`Patient/${patientId}`);
  });

  test('one failing entry rolls back the whole transaction', async ({ run, admin }) => {
    const id = run.id('tx-rollback');
    const res = await admin.post('/fhir', {
      data: {
        resourceType: 'Bundle',
        type: 'transaction',
        entry: [
          { resource: { resourceType: 'Patient', id }, request: { method: 'PUT', url: `Patient/${id}` } },
          { resource: { resourceType: 'Observation' }, request: { method: 'POST', url: 'Observation' } },
        ],
      },
    });
    expect(res.status()).toBeGreaterThanOrEqual(400);
    expect((await res.json()).resourceType).toBe('OperationOutcome');
    expect((await admin.get(`/fhir/Patient/${id}`)).status()).toBe(404);
  });
});
