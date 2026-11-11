/* ==========================================================================
   Prototype router.
   index.html?screen=ping&device=phone&theme=dark      → one screen
   index.html?device=tablet&theme=light                → gallery of every screen
   &static=1  freezes motion on the resting frame (used for screenshots)
   &live=0    disables the live-number tickers (they are on by default)
   ========================================================================== */
(function () {
  const P = window.Pulse;
  const SCREENS = [
    ['splash', 'Splash'], ['ping', 'Ping'], ['pingDetail', 'Ping detail'], ['network', 'Network'], ['tools', 'Tools'],
    ['trace', 'Traceroute'], ['ports', 'Port scan'], ['speed', 'Speed test'], ['loss', 'Packet loss'], ['lan', 'LAN scan'],
    ['geo', 'Geo IP'], ['monitor', 'Monitor'], ['history', 'History'], ['settings', 'Settings'],
  ];
  window.PULSE_SCREENS = SCREENS;
  const q = new URLSearchParams(location.search);
  const device = q.get('device') || 'phone';
  const theme = q.get('theme') || 'dark';
  const one = q.get('screen');
  const root = document.getElementById('root');
  if (q.get('zoom')) document.documentElement.style.zoom = q.get('zoom'); // used by tools/record.cjs for crisp video
  const lib = device === 'tablet' ? P.tablet : P.phone;

  const frame = (key) => `<div class="app ${device}${q.get('static') === '1' ? ' static' : ''}" data-theme="${theme}" data-screen="${key}">${lib[key]()}</div>`;

  if (one) {
    document.body.style.background = 'transparent';
    root.innerHTML = frame(one);
  } else {
    document.body.style.cssText = 'background:#0E0A10;margin:0;padding:32px;font-family:Roboto Flex, sans-serif;color:#eee';
    root.innerHTML = `<h1 style="font-weight:800;font-variation-settings:'wdth' 125;margin:0 0 8px">Pulse · ${device} · ${theme}</h1>
      <p style="margin:0 0 24px;opacity:.7">Switch: <a style="color:#FFAFD0" href="?device=phone&theme=dark">phone dark</a> · <a style="color:#FFAFD0" href="?device=phone&theme=light">phone light</a> · <a style="color:#FFAFD0" href="?device=tablet&theme=dark">tablet dark</a> · <a style="color:#FFAFD0" href="?device=tablet&theme=light">tablet light</a></p>
      <div style="display:flex;flex-wrap:wrap;gap:32px">${SCREENS.map(([k, t]) => `<figure style="margin:0"><figcaption style="margin:0 0 8px;font-weight:600">${t}</figcaption><div style="border-radius:${device === 'phone' ? 36 : 24}px;overflow:hidden">${frame(k)}</div></figure>`).join('')}</div>`;
  }

  /* Live numbers: elements with data-tick="key" jitter around their base value. */
  const GEN = {
    dns: [35, 3, 0.9], router: [4.8, 0.6, 1.3], cf: [8.0, 0.9, 1.7], gh: [54, 5, 1.1], single: [37, 3, 1.0],
    h0: [4.8, 0.6, 1.3], h1: [35, 3, 0.9], h2: [8.0, 0.9, 1.7], h3: [54, 5, 1.1], h4: [12, 1.5, 1.2], h5: [44, 4, 0.8],
    dl: [9.4, 0.6, 1.3], avg: [27, 2, 0.7],
  };
  if (q.get('live') !== '0' && q.get('static') !== '1') {
    let t = 0;
    setInterval(() => {
      t++;
      document.querySelectorAll('[data-tick]').forEach((el) => {
        const k = el.dataset.tick;
        if (k === 'secs') { el.textContent = (4 + ((t * 0.7) % 6)).toFixed(1) + ' s'; return; }
        const g = GEN[k]; if (!g) return;
        const v = g[0] + Math.sin(t * g[2]) * g[1] + Math.sin(t * g[2] * 2.3) * g[1] * 0.35;
        const keepSmall = el.querySelector('small');
        const txt = k === 'dl' ? v.toFixed(1) : P.fmt(v);
        if (keepSmall) { el.firstChild.nodeValue = txt; } else el.textContent = txt;
      });
    }, 900);
  }
})();
