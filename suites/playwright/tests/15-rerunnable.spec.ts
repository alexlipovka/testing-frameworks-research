import { test, expect } from '../lib/test';
import { sql } from '../lib/run';

// The second half of case 15 is `./run.sh twice`: two consecutive runs, both green
test('15. no residue from earlier runs: only this run\'s rows exist', async ({ run, admin }) => {
  const rows = await sql(
    admin,
    `SELECT 'Client' AS t, id FROM client WHERE id LIKE 'bakeoff-%' AND id NOT LIKE '${run.runId}-%'
     UNION ALL SELECT 'User', id FROM "user" WHERE id LIKE 'bakeoff-%' AND id NOT LIKE '${run.runId}-%'
     UNION ALL SELECT 'Patient', id FROM patient WHERE id LIKE 'bakeoff-%' AND id NOT LIKE '${run.runId}-%'`,
  );
  expect(rows).toEqual([]);
});
