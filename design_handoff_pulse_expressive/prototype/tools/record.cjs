// Records short motion clips (WebM) of selected screens with Playwright.
// Usage: node tools/record.cjs <outDir>
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const index = 'file://' + path.resolve(__dirname, '..', 'index.html');
const logoStage = 'file://' + path.resolve(__dirname, 'logo-stage.html');
const out = process.argv[2] || 'clips';
const CLIPS = [
  ['01-logo-splash-phone', 'phone', 'splash', 6000],
  ['02-ping-home-phone', 'phone', 'ping', 7000],
  ['03-speed-test-phone', 'phone', 'speed', 6000],
  ['04-traceroute-phone', 'phone', 'trace', 5000],
  ['05-tools-entrance-phone', 'phone', 'tools', 3500],
  ['06-geo-ip-route-phone', 'phone', 'geo', 5000],
  ['07-packet-loss-phone', 'phone', 'loss', 5000],
  ['08-ping-grid-tablet', 'tablet', 'ping', 6000],
  ['09-ping-detail-tablet', 'tablet', 'pingDetail', 6000],
  ['10-port-scan-tablet', 'tablet', 'ports', 4000],
];
(async () => {
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch();
  for (const [name, device, screen, ms] of (process.env.LOGO_ONLY ? [] : CLIPS)) {
    for (const theme of (process.env.ONLY_LIGHT ? ['light'] : ['dark', 'light'])) {
      if (theme === 'light' && !['02-ping-home-phone', '03-speed-test-phone', '08-ping-grid-tablet'].includes(name)) continue;
            const vs = device === 'phone' ? { width: 780, height: 1688 } : { width: 1920, height: 1200 };
      const ctx = await browser.newContext({ viewport: vs, deviceScaleFactor: 1, recordVideo: { dir: out, size: vs } });
      const page = await ctx.newPage();
      await page.goto(`${index}?screen=${screen}&device=${device}&theme=${theme}&zoom=${device === 'phone' ? 2 : 1.5}`);
      await page.waitForTimeout(ms);
      const v = page.video();
      await ctx.close();
      fs.renameSync(await v.path(), path.join(out, `${name}-${theme}.webm`));
      console.log('clip', name, theme);
    }
  }
  if (process.env.ONLY_LIGHT) { await browser.close(); return; }
  // Logo loop on its own
  const ctx = await browser.newContext({ viewport: { width: 1080, height: 1080 }, deviceScaleFactor: 1, recordVideo: { dir: out, size: { width: 1080, height: 1080 } } });
  const page = await ctx.newPage();
  await page.goto(logoStage);
  await page.waitForTimeout(5200);
  const v = page.video(); await ctx.close();
  fs.renameSync(await v.path(), path.join(out, `00-logo-loop.webm`));
  await browser.close();
})();
