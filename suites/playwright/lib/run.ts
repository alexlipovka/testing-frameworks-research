// The shared fixture contract (sut/fixtures/README.md): stamp, setup, tokens, teardown.
import { request, type APIRequestContext } from '@playwright/test';
import { randomBytes } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

export const AIDBOX_URL = process.env.AIDBOX_URL ?? 'http://localhost:8280';
const ADMIN = { username: 'root', password: 'secret' };
const FIXTURES = process.env.FIXTURES_JSON ?? new URL('../../../sut/fixtures/fixtures.json', import.meta.url).pathname;
// Outlives a crashed runner, so `./run.sh teardown` can still roll the run back
export const OPEN_RUN = process.env.OPEN_RUN_FILE ?? new URL('../reports/open-run.json', import.meta.url).pathname;

export type Identity = 'pat-self' | 'p1' | 'p2' | 'rec' | 'norole';
export type RunVars = { runId: string; txId: string; tokens: Record<Identity, string> };

export async function adminContext(): Promise<APIRequestContext> {
  return request.newContext({ baseURL: AIDBOX_URL, httpCredentials: { ...ADMIN, send: 'always' } });
}

export async function sql(admin: APIRequestContext, query: string) {
  const res = await admin.post('/$psql', { data: { query } });
  const body = await res.json();
  if (!res.ok() || body.status !== 'success') throw new Error(`$psql ${query}: ${JSON.stringify(body)}`);
  return (body.result[0]?.data ?? []) as Record<string, unknown>[];
}

function load(runId: string) {
  const raw = readFileSync(FIXTURES, 'utf8').replaceAll('{{run_id}}', runId);
  return JSON.parse(raw);
}

export async function openRun(): Promise<RunVars> {
  if (existsSync(OPEN_RUN)) throw new Error(`a run is open (${OPEN_RUN}): ./run.sh teardown first`);
  const runId = `bakeoff-${randomBytes(4).toString('hex')}`;
  const data = load(runId);
  const admin = await adminContext();
  try {
    await sql(admin, data.sql.install);
    const txId = String((await sql(admin, data.sql.stamp))[0].last_value);
    mkdirSync(dirname(OPEN_RUN), { recursive: true });
    writeFileSync(OPEN_RUN, JSON.stringify({ runId, txId }));
    try {
      for (const s of data.setup) {
        const res = await admin.fetch(s.path, { method: s.method, data: s.body });
        if (!res.ok()) throw new Error(`setup ${s.method} ${s.path}: ${res.status()} ${await res.text()}`);
      }
      const tokens = {} as Record<Identity, string>;
      for (const id of data.identities) {
        const anon = await request.newContext({ baseURL: AIDBOX_URL });
        const res = await anon.post('/auth/token', {
          data: {
            grant_type: 'password',
            client_id: data.secrets.client_id,
            client_secret: data.secrets.client_secret,
            username: id.user,
            password: data.secrets.user_password,
          },
        });
        const body = await res.text();
        await anon.dispose();
        if (!res.ok()) throw new Error(`token ${id.name}: ${res.status()} ${body}`);
        tokens[id.name as Identity] = JSON.parse(body).access_token;
      }
      return { runId, txId, tokens };
    } catch (e) {
      await closeRun({ runId, txId } as RunVars);
      throw e;
    }
  } finally {
    await admin.dispose();
  }
}

export async function closeRun(vars: Pick<RunVars, 'txId'>) {
  const admin = await adminContext();
  try {
    await sql(admin, load('unused').sql.rollback.replace('{{tx_id}}', vars.txId));
    rmSync(OPEN_RUN, { force: true });
  } finally {
    await admin.dispose();
  }
}
