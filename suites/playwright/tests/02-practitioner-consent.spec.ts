import { test } from '../lib/test';

test.describe('2. practitioner via Consent (SQL)', () => {
  test('allow: p1 reads a patient with an active Consent', async ({ run, allows }) => {
    await allows('p1', { path: `/fhir/Patient/${run.id('patient-self')}` }, 'practitioner-policy');
  });

  test('allow: p2 reads a patient with an active Consent', async ({ run, allows }) => {
    await allows('p2', { path: `/fhir/Patient/${run.id('patient-other')}` }, 'practitioner-policy');
  });

  test('deny: p1 on a patient whose Consent is revoked', async ({ run, denies }) => {
    await denies('p1', { path: `/fhir/Patient/${run.id('patient-other')}` });
  });

  test('deny: p2 on a patient consented only to p1', async ({ run, denies }) => {
    await denies('p2', { path: `/fhir/Patient/${run.id('patient-self')}` });
  });

  test('deny: nobody is consented to the unlinked patient', async ({ run, denies }) => {
    await denies('p1', { path: `/fhir/Patient/${run.id('patient-unlinked')}` });
    await denies('p2', { path: `/fhir/Patient/${run.id('patient-unlinked')}` });
  });
});
