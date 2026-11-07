import { test, expect, type Identity, type Req } from '../lib/test';

const populate = (patient: string): Req => ({
  method: 'POST',
  path: '/fhir/Questionnaire/glucose/$populate',
  data: { resourceType: 'Parameters', parameter: [{ name: 'subject', valueReference: { reference: `Patient/${patient}` } }] },
});

const extract = (subject: string, patientIdAnswer: string): Req => ({
  method: 'POST',
  path: '/fhir/Questionnaire/glucose/$extract',
  data: {
    resourceType: 'Parameters',
    parameter: [
      {
        name: 'questionnaire_response',
        resource: {
          resourceType: 'QuestionnaireResponse',
          questionnaire: 'glucose',
          status: 'completed',
          subject: { reference: `Patient/${subject}` },
          item: [
            { linkId: 'patientId', answer: [{ valueString: patientIdAnswer }] },
            { linkId: 'glucose-level', answer: [{ valueDecimal: 5.5 }] },
          ],
        },
      },
    ],
  },
});

const SDC_POLICY = 'as-practitioner-sdc-consented-patient';

test.describe('9. SDC $populate / $extract under each role', () => {
  // Spec: allowed calls assert the policy gate, not the mapping output (no launch context in the SUT)
  const passesGate = async (verdict: any, as: any, who: Identity, req: Req) => {
    const v = await verdict(who, req);
    expect(v.errors).toEqual([]);
    expect(v.granted).toContain(SDC_POLICY);
    const res = await (await as(who)).fetch(req.path, { method: req.method, data: req.data });
    expect(res.status(), await res.text()).not.toBe(403);
  };

  test('allow: p1 populates for a consented patient', async ({ run, verdict, as }) => {
    await passesGate(verdict, as, 'p1', populate(run.id('patient-self')));
  });

  test('allow: p2 populates for a consented patient', async ({ run, verdict, as }) => {
    await passesGate(verdict, as, 'p2', populate(run.id('patient-other')));
  });

  test('deny: $populate for an unconsented patient', async ({ run, denies }) => {
    await denies('p1', populate(run.id('patient-other')));
    await denies('p2', populate(run.id('patient-self')));
    await denies('p1', populate(run.id('patient-unlinked')));
  });

  test('deny: $populate by patient, receptionist and no-role', async ({ run, denies }) => {
    for (const who of ['pat-self', 'rec', 'norole'] as Identity[]) await denies(who, populate(run.id('patient-self')));
  });

  test('allow: p1 extracts a QR whose subject and patientId match a consented patient', async ({ run, verdict, as }) => {
    const self = run.id('patient-self');
    await passesGate(verdict, as, 'p1', extract(self, self));
  });

  test('deny: forged patientId answer pointing at another patient', async ({ run, denies }) => {
    await denies('p1', extract(run.id('patient-self'), run.id('patient-other')));
  });

  test('deny: QR subject is a patient the practitioner is not consented to', async ({ run, denies }) => {
    const other = run.id('patient-other');
    await denies('p1', extract(other, other));
  });

  test('allow: the same QR is fine for the practitioner who is consented', async ({ run, verdict, as }) => {
    const other = run.id('patient-other');
    await passesGate(verdict, as, 'p2', extract(other, other));
  });

  test('deny: $extract by patient, receptionist and no-role', async ({ run, denies }) => {
    const self = run.id('patient-self');
    for (const who of ['pat-self', 'rec', 'norole'] as Identity[]) await denies(who, extract(self, self));
  });
});
