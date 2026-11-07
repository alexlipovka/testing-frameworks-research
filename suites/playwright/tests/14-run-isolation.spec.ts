import { test, expect } from '../lib/test';
import { sql } from '../lib/run';

test.describe('14. run_id isolation', () => {
  test('every fixture carries the run_id and was written after the stamp', async ({ run, admin }) => {
    const rows = await sql(
      admin,
      `SELECT 'Patient' AS t, id, txid FROM patient WHERE id LIKE '${run.runId}-%'
       UNION ALL SELECT 'Consent', id, txid FROM consent WHERE id LIKE '${run.runId}-%'
       UNION ALL SELECT 'User', id, txid FROM "user" WHERE id LIKE '${run.runId}-%'`,
    );
    expect(rows.filter((r) => r.t === 'Patient')).toHaveLength(3);
    expect(rows.filter((r) => r.t === 'Consent')).toHaveLength(3);
    expect(rows.filter((r) => r.t === 'User')).toHaveLength(5);
    for (const r of rows) expect(Number(r.txid), `${r.t}/${r.id}`).toBeGreaterThan(Number(run.txId));
  });

  test('a server-generated id is still inside the run, so teardown removes it', async ({ admin, run }) => {
    const created = await (await admin.post('/fhir/Patient', { data: { resourceType: 'Patient' } })).json();
    const [row] = await sql(admin, `SELECT txid FROM patient WHERE id = '${created.id}'`);
    expect(Number(row.txid)).toBeGreaterThan(Number(run.txId));
  });

  test('identities only see this run: the tokens resolve to run-prefixed users', async ({ run, as }) => {
    for (const who of ['pat-self', 'p1', 'p2', 'rec', 'norole'] as const) {
      const ctx = await as(who);
      const res = await ctx.get(`/fhir/Patient/${run.id('patient-self')}?__debug=policy`);
      const dump = await res.json();
      expect(dump.request.user.id).toBe(run.id(who));
    }
  });
});
