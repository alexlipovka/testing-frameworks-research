import { openRun, closeRun } from './run';

// Workers inherit process.env, so the run's ids and tokens travel through it
export default async function globalSetup() {
  const vars = await openRun();
  process.env.BAKEOFF_RUN = JSON.stringify(vars);
  return async () => closeRun(vars);
}
