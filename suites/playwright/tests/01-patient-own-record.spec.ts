import { test } from '../lib/test';

test.describe('1. patient reads own record (matcho)', () => {
  test('allow: own Patient', async ({ run, allows }) => {
    await allows('pat-self', { path: `/fhir/Patient/${run.id('patient-self')}` }, 'patient-role-policy');
  });

  test("deny: another patient's record", async ({ run, denies }) => {
    await denies('pat-self', { path: `/fhir/Patient/${run.id('patient-other')}` });
  });
});
