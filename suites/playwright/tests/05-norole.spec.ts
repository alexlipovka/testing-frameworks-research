import { test } from '../lib/test';

test.describe('5. an identity without a role is denied everywhere', () => {
  const requests = (id: (f: string) => string) => [
    { path: `/fhir/Patient/${id('patient-self')}` },
    { path: `/fhir/Patient?_id=${id('patient-self')}` },
    { path: `/fhir/Patient` },
    { path: `/fhir/Encounter/${id('enc-match')}` },
    { path: `/fhir/Observation?subject=Patient/${id('patient-self')}` },
    { path: `/fhir/Appointment/${id('appt-match')}` },
    { method: 'POST', path: '/fhir/Patient', data: { resourceType: 'Patient' } },
    {
      method: 'POST',
      path: '/fhir/Questionnaire/glucose/$populate',
      data: { resourceType: 'Parameters', parameter: [{ name: 'subject', valueReference: { reference: `Patient/${id('patient-self')}` } }] },
    },
  ];

  test('deny: reads, searches, writes and SDC operations', async ({ run, denies }) => {
    for (const req of requests(run.id)) await denies('norole', req);
  });

  test('allow (control): admin can do the same reads', async ({ run, admin }) => {
    const res = await admin.get(`/fhir/Patient/${run.id('patient-self')}`);
    test.expect(res.status()).toBe(200);
  });
});
