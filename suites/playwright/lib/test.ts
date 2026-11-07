import { test as base, expect, request, type APIRequestContext, type APIResponse } from '@playwright/test';
import { AIDBOX_URL, adminContext, type Identity, type RunVars } from './run';

export { expect };
export type { Identity };

export type Req = {
  method?: string;
  path: string;
  data?: unknown;
  headers?: Record<string, string>;
};

export type Verdict = {
  granted: string[];
  /** policies whose evaluation crashed */
  errors: { id: string; error: string }[];
};

type Fixtures = {
  run: RunVars & { id: (fixture: string) => string };
  admin: APIRequestContext;
  as: (who: Identity) => Promise<APIRequestContext>;
  /** The decision as `__debug=policy` reports it; the request itself is not executed */
  verdict: (who: Identity | APIRequestContext, req: Req) => Promise<Verdict>;
  /** Debug dump grants via `policyId` with no policy errors, and the real request succeeds */
  allows: (who: Identity, req: Req, policyId: string) => Promise<APIResponse>;
  /** Debug dump grants nothing with no policy errors, and the real request is a 403 */
  denies: (who: Identity, req: Req) => Promise<APIResponse>;
};

function send(ctx: APIRequestContext, req: Req, extraQuery = '') {
  const path = extraQuery ? req.path + (req.path.includes('?') ? '&' : '?') + extraQuery : req.path;
  return ctx.fetch(path, { method: req.method ?? 'GET', data: req.data, headers: req.headers });
}

const describe = (who: Identity | string, req: Req) => `${who} ${req.method ?? 'GET'} ${req.path}`;

export const test = base.extend<Fixtures>({
  run: async ({}, use) => {
    const vars: RunVars = JSON.parse(process.env.BAKEOFF_RUN ?? 'null');
    if (!vars) throw new Error('BAKEOFF_RUN is not set: globalSetup did not run');
    await use({ ...vars, id: (f) => `${vars.runId}-${f}` });
  },

  admin: async ({}, use) => {
    const ctx = await adminContext();
    await use(ctx);
    await ctx.dispose();
  },

  as: async ({ run }, use) => {
    const opened: APIRequestContext[] = [];
    await use(async (who) => {
      const ctx = await request.newContext({
        baseURL: AIDBOX_URL,
        extraHTTPHeaders: { authorization: `Bearer ${run.tokens[who]}` },
      });
      opened.push(ctx);
      return ctx;
    });
    await Promise.all(opened.map((c) => c.dispose()));
  },

  verdict: async ({ as }, use) => {
    await use(async (who, req) => {
      const ctx = typeof who === 'string' ? await as(who) : who;
      const res = await send(ctx, req, '__debug=policy');
      expect(res.status(), `debug dump for ${describe(String(who), req)}: ${await res.text()}`).toBe(200);
      const dump = await res.json();
      const policies: any[] = dump.policies ?? [];
      return {
        granted: policies.filter((p) => p['eval-result'] === true).map((p) => p.id),
        errors: policies.filter((p) => p.error).map((p) => ({ id: p.id, error: p.error })),
      };
    });
  },

  allows: async ({ as, verdict }, use) => {
    await use(async (who, req, policyId) => {
      const v = await verdict(who, req);
      expect(v.errors, `policy errors on ${describe(who, req)}`).toEqual([]);
      expect(v.granted, `granting policies on ${describe(who, req)}`).toContain(policyId);
      const res = await send(await as(who), req);
      expect(res.status(), `${describe(who, req)}: ${await res.text()}`).toBeLessThan(300);
      return res;
    });
  },

  denies: async ({ as, verdict }, use) => {
    await use(async (who, req) => {
      const v = await verdict(who, req);
      expect(v.errors, `policy errors on ${describe(who, req)}`).toEqual([]);
      expect(v.granted, `granting policies on ${describe(who, req)}`).toEqual([]);
      const res = await send(await as(who), req);
      expect(res.status(), `${describe(who, req)}: ${await res.text()}`).toBe(403);
      return res;
    });
  },
});
