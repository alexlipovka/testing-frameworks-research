import { test, expect } from '../lib/test';

test.describe('3. a SQL policy that throws is an error, not a plain deny', () => {
  test('a crashing SQL policy shows up in the debug dump although the client only sees 403', async ({ run, verdict, as }) => {
    // `parameter` must be an array; the SDC policy runs jsonb_array_elements on it
    const req = {
      method: 'POST',
      path: '/fhir/Questionnaire/glucose/$populate',
      data: { resourceType: 'Parameters', parameter: { name: 'subject', valueReference: { reference: `Patient/${run.id('patient-self')}` } } },
    };
    const v = await verdict('p1', req);
    expect(v.granted).toEqual([]);
    expect(v.errors.map((e) => e.id)).toContain('as-practitioner-sdc-consented-patient');
    const res = await (await as('p1')).fetch(req.path, { method: 'POST', data: req.data });
    expect(res.status()).toBe(403);
  });

  test('no policy crashes on patient requests, allowed or denied', async ({ run, verdict }) => {
    const requests = [
      `/fhir/Patient/${run.id('patient-self')}`,
      `/fhir/Patient/${run.id('patient-other')}`,
      `/fhir/Encounter/${run.id('enc-match')}`,
      `/fhir/Encounter/${run.id('enc-mismatch')}`,
      `/fhir/Observation?subject=Patient/${run.id('patient-self')}`,
      `/fhir/Condition/${run.id('cond-match')}`,
    ];
    for (const path of requests) {
      const v = await verdict('pat-self', { path });
      expect(v.errors, `policy errors on pat-self GET ${path}`).toEqual([]);
    }
  });
});
