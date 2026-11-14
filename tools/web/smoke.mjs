// Headless-Chrome smoke test for the Lost Origin web build.
// usage: node tools/web/smoke.mjs <url> [--headed] [--fps-seconds N] [--shot path]
// Passes when: page reaches the title (window.__lost_origin.state == "title")
// with no console/page errors, and Enter reaches "playing". Prints SMOKE_* lines.
import { chromium } from 'playwright-core';

const args = process.argv.slice(2);
const url = args.find((a) => !a.startsWith('--')) || 'http://127.0.0.1:8765/';
const headed = args.includes('--headed');
const fpsIdx = args.indexOf('--fps-seconds');
const fpsSeconds = fpsIdx >= 0 ? Number(args[fpsIdx + 1]) : 4;
const shotIdx = args.indexOf('--shot');
const shot = shotIdx >= 0 ? args[shotIdx + 1] : 'build/smoke.png';

const errors = [];
const IGNORE = [/favicon/i, /AudioContext was not allowed/i, /The AudioContext was not allowed to start/i];
const browser = await chromium.launch({
  channel: 'chrome',
  headless: !headed,
  args: ['--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-gpu', '--use-angle=metal', '--autoplay-policy=no-user-gesture-required'],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on('console', (m) => {
  if (m.type() === 'error' && !IGNORE.some((r) => r.test(m.text()))) errors.push('console: ' + m.text());
});
page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));

const state = () => page.evaluate(() => (window.__lost_origin || {}).state || 'none');
async function waitState(want, ms) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) {
    const s = await state();
    if (s === want) return true;
    if (s === 'error') return false;
    await page.waitForTimeout(250);
  }
  return false;
}

let ok = true;
const t0 = Date.now();
await page.goto(url, { waitUntil: 'load', timeout: 60000 });
const reachedTitle = await waitState('title', 60000);
console.log(`SMOKE_TITLE ${reachedTitle} after ${((Date.now() - t0) / 1000).toFixed(1)}s`);
ok = ok && reachedTitle;
const webgl = await page.evaluate(() => {
  const c = document.createElement('canvas');
  const gl = c.getContext('webgl2');
  if (!gl) return 'none';
  const dbg = gl.getExtension('WEBGL_debug_renderer_info');
  return dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : 'webgl2';
});
console.log(`SMOKE_WEBGL ${webgl}`);
if (reachedTitle) {
  await page.waitForTimeout(1500);
  await page.locator('#canvas').click({ position: { x: 640, y: 600 } }).catch(() => {});
  await page.keyboard.press('Enter');
  const playing = await waitState('playing', 30000);
  console.log(`SMOKE_PLAYING ${playing}`);
  ok = ok && playing;
  if (playing) {
    await page.waitForTimeout(1000);
    const samples = [];
    for (let i = 0; i < fpsSeconds * 2; i++) {
      await page.waitForTimeout(500);
      samples.push(await page.evaluate(() => (window.__lost_origin || {}).fps || 0));
    }
    const avg = samples.reduce((a, b) => a + b, 0) / Math.max(samples.length, 1);
    console.log(`SMOKE_FPS avg=${avg.toFixed(1)} min=${Math.min(...samples)} renderer=${await page.evaluate(() => (window.__lost_origin || {}).renderer)}`);
  }
}
await page.screenshot({ path: shot }).catch(() => {});
console.log(`SMOKE_ERRORS ${errors.length}`);
for (const e of errors.slice(0, 20)) console.log('  ' + e);
ok = ok && errors.length === 0;
await browser.close();
console.log(ok ? 'SMOKE_OK' : 'SMOKE_FAIL');
process.exit(ok ? 0 : 1);
