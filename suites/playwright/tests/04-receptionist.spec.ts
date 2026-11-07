import { test } from '../lib/test';

test.describe('4. receptionist reads but does not write Patients', () => {
  test('allow: read a Patient by id', async ({ run, allows }) => {
    await allows('rec', { path: `/fhir/Patient/${run.id('patient-self')}` }, 'as-receptionist-read-patients');
  });

  test('allow: search Patients', async ({ run, allows }) => {
    await allows('rec', { path: `/fhir/Patient?_id=${run.id('patient-self')},${run.id('patient-other')}` }, 'as-receptionist-read-patients');
  });

  test('allow: Appointments are the receptionist\'s to manage', async ({ run, allows }) => {
    await allows('rec', { path: `/fhir/Appointment/${run.id('appt-match')}` }, 'receptionist-role-policy');
  });

  test('deny: PUT a Patient', async ({ run, denies }) => {
    const id = run.id('patient-self');
    await denies('rec', {
      method: 'PUT',
      path: `/fhir/Patient/${id}`,
      data: { resourceType: 'Patient', id, name: [{ given: ['Renamed'], family: 'Bakeoff' }] },
    });
  });

  test('deny: POST a Patient', async ({ denies }) => {
    await denies('rec', { method: 'POST', path: '/fhir/Patient', data: { resourceType: 'Patient', name: [{ family: 'Bakeoff' }] } });
  });

  test('deny: JSON Patch a Patient', async ({ run, denies }) => {
    await denies('rec', {
      method: 'PATCH',
      path: `/fhir/Patient/${run.id('patient-self')}`,
      headers: { 'content-type': 'application/json-patch+json' },
      data: JSON.stringify([{ op: 'replace', path: '/name/0/family', value: 'Patched' }]),
    });
  });
});
