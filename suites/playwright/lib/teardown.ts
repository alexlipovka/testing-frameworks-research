// Rolls back a run whose runner died before its global teardown: node lib/teardown.ts
import { existsSync, readFileSync } from 'node:fs';
import { OPEN_RUN, closeRun } from './run.ts';

if (existsSync(OPEN_RUN)) {
  const vars = JSON.parse(readFileSync(OPEN_RUN, 'utf8'));
  await closeRun(vars);
  console.log(`run ${vars.runId} rolled back to tx ${vars.txId}`);
} else console.log('no open run');
