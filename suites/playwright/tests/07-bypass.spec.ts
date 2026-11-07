import { test } from '../lib/test';

const bundle = (...entry: any[]) => ({ resourceType: 'Bundle', type: 'transaction', entry });

test.describe('7. bypass attempts', () => {
  test("deny: patient reads another patient's record inside a transaction Bundle", async ({ run, denies }) => {
    await denies('pat-self', {
      method: 'POST',
      path: '/fhir',
      data: bundle({ request: { method: 'GET', url: `Patient/${run.id('patient-other')}` } }),
    });
  });

  test('deny: even a request the patient may make on its own is refused inside a Bundle', async ({ run, denies }) => {
    await denies('pat-self', {
      method: 'POST',
      path: '/fhir',
      data: bundle({ request: { method: 'GET', url: `Patient/${run.id('patient-self')}` } }),
    });
  });

  test('deny: receptionist writes a Patient inside a transaction Bundle', async ({ run, denies }) => {
    const id = run.id('patient-self');
    await denies('rec', {
      method: 'POST',
      path: '/fhir',
      data: bundle({
        resource: { resourceType: 'Patient', id, name: [{ family: 'Smuggled' }] },
        request: { method: 'PUT', url: `Patient/${id}` },
      }),
    });
  });

  test('deny: receptionist JSON-Patches a Patient', async ({ run, denies }) => {
    await denies('rec', {
      method: 'PATCH',
      path: `/fhir/Patient/${run.id('patient-other')}`,
      headers: { 'content-type': 'application/json-patch+json' },
      data: JSON.stringify([{ op: 'add', path: '/active', value: false }]),
    });
  });

  test('deny: receptionist merge-patches a Patient', async ({ run, denies }) => {
    await denies('rec', {
      method: 'PATCH',
      path: `/fhir/Patient/${run.id('patient-other')}`,
      headers: { 'content-type': 'application/merge-patch+json' },
      data: JSON.stringify({ active: false }),
    });
  });

  test('deny: patient JSON-Patches own record', async ({ run, denies }) => {
    await denies('pat-self', {
      method: 'PATCH',
      path: `/fhir/Patient/${run.id('patient-self')}`,
      headers: { 'content-type': 'application/json-patch+json' },
      data: JSON.stringify([{ op: 'replace', path: '/name/0/family', value: 'Patched' }]),
    });
  });
});
