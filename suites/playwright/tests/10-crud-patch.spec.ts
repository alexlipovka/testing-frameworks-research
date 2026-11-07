import { test, expect } from '../lib/test';

test('10. CRUD + JSON Patch', async ({ run, admin }) => {
  const created = await admin.post('/fhir/Patient', {
    data: { resourceType: 'Patient', name: [{ given: ['Crud'], family: run.runId }] },
  });
  expect(created.status()).toBe(201);
  const patient = await created.json();
  expect(patient.id).toBeTruthy();
  const path = `/fhir/Patient/${patient.id}`;

  const read = await admin.get(path);
  expect(read.status()).toBe(200);
  expect((await read.json()).name[0].given).toEqual(['Crud']);

  const updated = await admin.put(path, { data: { ...patient, gender: 'female' } });
  expect(updated.status()).toBe(200);
  expect((await updated.json()).gender).toBe('female');

  const patched = await admin.patch(path, {
    headers: { 'content-type': 'application/json-patch+json' },
    data: JSON.stringify([
      { op: 'replace', path: '/gender', value: 'male' },
      { op: 'add', path: '/birthDate', value: '2000-01-01' },
    ]),
  });
  expect(patched.status(), await patched.text()).toBe(200);
  const afterPatch = await (await admin.get(path)).json();
  expect(afterPatch).toMatchObject({ gender: 'male', birthDate: '2000-01-01', name: [{ given: ['Crud'] }] });

  expect((await admin.delete(path)).status()).toBe(200);
  expect([404, 410]).toContain((await admin.get(path)).status());
});
