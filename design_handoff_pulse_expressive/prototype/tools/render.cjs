// Renders every screen × device × theme to PNG with Playwright.
// Usage: node tools/render.cjs <outDir> [device] [theme] [screen]
const { chromium } = require('playwright');
const path = require('path');
const here = __dirname;
const index = 'file://' + path.resolve(here, '..', 'index.html');
const out = process.argv[2] || 'shots';
const devs = process.argv[3] ? [process.argv[3]] : ['phone', 'tablet'];
const themes = process.argv[4] ? [process.argv[4]] : ['dark', 'light'];
const only = process.argv[5];
const SCREENS = ['splash','ping','pingDetail','network','tools','trace','ports','speed','loss','lan','geo','monitor','history','settings'];
const NAMES = { splash:'01-splash', ping:'02-ping', pingDetail:'03-ping-detail', network:'04-network', tools:'05-tools', trace:'06-traceroute', ports:'07-port-scan', speed:'08-speed-test', loss:'09-packet-loss', lan:'10-lan-scan', geo:'11-geo-ip', monitor:'12-monitor', history:'13-history', settings:'14-settings' };
(async () => {
const browser = await chromium.launch();
for (const device of devs) {
  const size = device === 'phone' ? { width: 390, height: 844 } : { width: 1280, height: 800 };
  const ctx = await browser.newContext({ viewport: size, deviceScaleFactor: device === 'phone' ? 2 : 1.5 });
  const page = await ctx.newPage();
  page.on('pageerror', (e) => console.error('PAGEERROR', device, e.message));
  for (const theme of themes) {
    for (const s of SCREENS) {
      if (only && s !== only) continue;
      await page.goto(`${index}?screen=${s}&device=${device}&theme=${theme}&static=1`);
      await page.evaluate(() => document.fonts.ready);
      await page.waitForTimeout(150);
      const el = await page.$('.app');
      const file = path.join(out, device, theme, NAMES[s] + '.png');
      await el.screenshot({ path: file });
      console.log('ok', file);
    }
  }
  await ctx.close();
}
await browser.close();
})();
