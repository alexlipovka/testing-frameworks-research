import { test } from '../lib/test';

test.describe('1. patient reads own record (matcho)', () => {
  test('allow: own Patient', async ({ run, allows }) => {
    await allows('pat-self', { path: `/fhir/Patient/${run.id('patient-self')}` }, 'patient-role-policy');
  });

  test("deny: another patient's record", async ({ run, denies }) => {
    await denies('pat-self', { path: `/fhir/Patient/${run.id('patient-other')}` });
  });

  test('allow: own Encounter', async ({ run, allows }) => {
    await allows('pat-self', { path: `/fhir/Encounter/${run.id('enc-match')}` }, 'as-patient-read-own-encounter');
  });

  test("deny: another patient's Encounter", async ({ run, denies }) => {
    await denies('pat-self', { path: `/fhir/Encounter/${run.id('enc-mismatch')}` });
  });

  test('deny: an Encounter id under another resource type', async ({ run, denies }) => {
    await denies('pat-self', { path: `/fhir/Observation/${run.id('enc-match')}` });
  });
});
