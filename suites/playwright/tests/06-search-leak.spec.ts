import { test, expect } from '../lib/test';

const ids = (bundle: any) => (bundle.entry ?? []).map((e: any) => `${e.resource.resourceType}/${e.resource.id}`);

test.describe('6. searches return nothing outside the caller\'s scope', () => {
  test('allow: patient searches own Observations and gets only them', async ({ run, allows }) => {
    for (const subject of [`Patient/${run.id('patient-self')}`, run.id('patient-self')]) {
      const res = await allows('pat-self', { path: `/fhir/Observation?subject=${subject}` }, 'as-patient-search-own-observations');
      const bundle = await res.json();
      expect(ids(bundle)).toEqual([`Observation/${run.id('obs-match')}`]);
    }
  });

  test("deny: patient searches another patient's Observations", async ({ run, denies }) => {
    await denies('pat-self', { path: `/fhir/Observation?subject=Patient/${run.id('patient-other')}` });
  });

  test('deny: patient smuggles a second subject', async ({ run, denies }) => {
    await denies('pat-self', {
      path: `/fhir/Observation?subject=Patient/${run.id('patient-self')}&subject=Patient/${run.id('patient-other')}`,
    });
  });

  test('deny: patient searches all Observations', async ({ denies }) => {
    await denies('pat-self', { path: '/fhir/Observation' });
  });

  test('deny: patient adds an _include', async ({ run, denies }) => {
    await denies('pat-self', { path: `/fhir/Observation?subject=Patient/${run.id('patient-self')}&_include=Observation:subject` });
  });

  test('allow: practitioner searches consented patients and gets only them', async ({ run, allows }) => {
    const res = await allows('p1', { path: `/fhir/Patient?_id=${run.id('patient-self')}` }, 'as-practitioner-search-consented-patients');
    expect(ids(await res.json())).toEqual([`Patient/${run.id('patient-self')}`]);
  });

  test('deny: practitioner searches a consented and an unconsented patient', async ({ run, denies }) => {
    await denies('p1', { path: `/fhir/Patient?_id=${run.id('patient-self')},${run.id('patient-other')}` });
  });

  test('deny: practitioner adds a _revinclude', async ({ run, denies }) => {
    await denies('p1', { path: `/fhir/Patient?_id=${run.id('patient-self')}&_revinclude=Observation:subject` });
  });

  test('deny: receptionist pulls Observations in through _revinclude', async ({ run, denies }) => {
    await denies('rec', { path: `/fhir/Patient?_id=${run.id('patient-self')}&_revinclude=Observation:subject` });
  });

  test('deny: receptionist pulls Patients in through an Appointment _include', async ({ run, denies }) => {
    await denies('rec', { path: `/fhir/Appointment?_id=${run.id('appt-match')}&_include=Appointment:actor` });
  });
});
