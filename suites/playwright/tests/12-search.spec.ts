import { test, expect } from '../lib/test';

const ids = (bundle: any, mode?: string) =>
  (bundle.entry ?? [])
    .filter((e: any) => !mode || e.search?.mode === mode)
    .map((e: any) => `${e.resource.resourceType}/${e.resource.id}`)
    .sort();

test.describe('12. search: _include, _revinclude, chaining', () => {
  test('_include brings the subject Patient', async ({ run, admin }) => {
    const res = await admin.get(`/fhir/Observation?_id=${run.id('obs-match')}&_include=Observation:subject`);
    expect(res.status()).toBe(200);
    const bundle = await res.json();
    expect(ids(bundle, 'match')).toEqual([`Observation/${run.id('obs-match')}`]);
    expect(ids(bundle, 'include')).toEqual([`Patient/${run.id('patient-self')}`]);
  });

  test('_revinclude brings the Encounters pointing at the Patient', async ({ run, admin }) => {
    const res = await admin.get(`/fhir/Patient?_id=${run.id('patient-self')}&_revinclude=Encounter:subject`);
    const bundle = await res.json();
    expect(ids(bundle, 'include')).toEqual([`Encounter/${run.id('enc-match')}`]);
  });

  test('chained parameter filters by the referenced Patient', async ({ run, admin }) => {
    const res = await admin.get(
      `/fhir/Observation?_id=${run.id('obs-match')},${run.id('obs-mismatch')}&subject:Patient.name=Self`,
    );
    expect(res.status()).toBe(200);
    expect(ids(await res.json())).toEqual([`Observation/${run.id('obs-match')}`]);
  });
});
