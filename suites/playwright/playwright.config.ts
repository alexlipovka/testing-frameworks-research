import { defineConfig } from '@playwright/test';
import { AIDBOX_URL } from './lib/run';

export default defineConfig({
  testDir: './tests',
  globalSetup: './lib/global-setup.ts',
  fullyParallel: true,
  workers: process.env.WORKERS ? Number(process.env.WORKERS) : 4,
  retries: 0,
  reporter: [['list'], ['junit', { outputFile: 'reports/junit.xml' }], ['html', { open: 'never', outputFolder: 'reports/html' }]],
  use: { baseURL: AIDBOX_URL },
});
