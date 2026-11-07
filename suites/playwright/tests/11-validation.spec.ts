import { test, expect } from '../lib/test';

test.describe('11. validation errors come back as OperationOutcome', () => {
  test('wrong type for a known element', async ({ admin }) => {
    const res = await admin.post('/fhir/Patient', { data: { resourceType: 'Patient', birthDate: 'not-a-date' } });
    expect(res.status()).toBe(422);
    const oo = await res.json();
    expect(oo.resourceType).toBe('OperationOutcome');
    expect(oo.issue.length).toBeGreaterThan(0);
    expect(oo.issue[0].severity).toMatch(/error|fatal/);
  });

  test('unknown element', async ({ admin }) => {
    const res = await admin.post('/fhir/Patient', { data: { resourceType: 'Patient', notAnElement: true } });
    expect(res.status()).toBe(422);
    expect((await res.json()).resourceType).toBe('OperationOutcome');
  });

  test('missing required element', async ({ admin }) => {
    // Observation.status and Observation.code are 1..1
    const res = await admin.post('/fhir/Observation', { data: { resourceType: 'Observation' } });
    expect(res.status()).toBe(422);
    expect((await res.json()).resourceType).toBe('OperationOutcome');
  });
});
