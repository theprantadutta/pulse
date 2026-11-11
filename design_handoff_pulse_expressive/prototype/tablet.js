/* ==========================================================================
   Pulse — tablet screens (1280 × 800 landscape). Navigation rail on the left;
   tool screens use the list-detail canonical layout (tools pane + content).
   ========================================================================== */
(function () {
  const P = window.Pulse, D = window.PulseData, ic = P.icon;
  const T = (P.tablet = {});
  const d = (s) => `animation-delay:${s}s`;
  const main = (inner, pad = '24px 28px 24px 16px') => `<main style="flex:1;min-width:0;height:100%;padding:${pad};display:flex;flex-direction:column;position:relative">${inner}</main>`;
  const toolFrame = (active, inner) => `${P.rail('tools')}${P.toolsPane(active)}${main(inner, '20px 28px 20px 24px')}`;
  const head = (title, right = '', sub = '') => `<header class="row" style="gap:12px;min-height:56px;flex:none"><div class="col grow"><h1 class="t-h2" style="margin:0">${title}</h1>${sub ? `<span class="t-sup">${sub}</span>` : ''}</div>${right}</header>`;

  // Route rail (21 hops) scaled to width w
  P.hopRail = function (w) {
    const step = (w - 16) / 20, xs = [...Array(21)].map((_, i) => 8 + i * step);
    const y = (i) => 28 + 9 * Math.sin(i * 0.62);
    let wave = ''; for (let k = 0; k <= w - 16; k += 3) { const i = k / step; wave += (k ? 'L' : 'M') + (8 + k) + ' ' + y(i).toFixed(1); }
    const col = (i) => (i <= 5 || i === 7) ? 'var(--lat-fast)' : i === 6 ? 'var(--lat-mid)' : 'var(--lat-slow)';
    const nodes = xs.map((x, i) => {
      if (i === 8 || i === 9) return `<circle class="a-node" style="animation-delay:${(0.1 + i * 0.04).toFixed(2)}s;fill:var(--surface-c);stroke:var(--outline)" stroke-width="2" stroke-dasharray="2 2" cx="${x.toFixed(1)}" cy="${y(i).toFixed(1)}" r="4.5"/>`;
      if (i === 20) return `<path class="a-spin-f" style="fill:var(--pink);stroke:var(--surface-c)" stroke-width="2" d="${P.polar(x, y(i), 11.5, 1.6, 9, 90)}"/>`;
      return `<circle class="a-node" style="animation-delay:${(0.1 + i * 0.04).toFixed(2)}s;fill:${col(i)}" cx="${x.toFixed(1)}" cy="${y(i).toFixed(1)}" r="5"/>`;
    }).join('');
    const jx = xs[10];
    return `<svg width="${w}" height="72" viewBox="0 0 ${w} 72" style="overflow:visible" role="img" aria-label="Route overview, 21 hops">
      <path class="a-draw" style="--len:${w + 60};stroke-dasharray:${w + 60};stroke:var(--secondary-c)" d="${wave}" fill="none" stroke-width="3" stroke-linecap="round"/>${nodes}
      <g class="a-bob"><rect x="${jx - 18}" y="0" width="36" height="16" rx="8" style="fill:var(--primary-c)"/><text x="${jx}" y="11.5" text-anchor="middle" font-size="10" font-weight="800" style="fill:var(--on-primary-c)" font-family="Roboto Flex">+55</text></g>
      <g font-family="Roboto Flex" font-size="11" font-weight="600" style="fill:var(--on-surface-var)"><text x="2" y="62">You</text><text x="${xs[3]}" y="62" text-anchor="middle">Bangladesh</text><text x="${w - 2}" y="62" text-anchor="end">Singapore</text></g>
    </svg>`;
  };

  const hostLead = (i) => [
    `<span style="width:40px;height:40px;border-radius:50%;background:var(--tertiary-c);color:var(--on-tertiary-c);display:grid;place-items:center">${ic('router', 20)}</span>`,
    `<span style="position:relative;width:40px;height:40px;display:grid;place-items:center;color:var(--on-pink)">${P.shape('cookie9', 40, 'var(--pink)', { style: 'position:absolute;inset:0' })}<span style="position:relative">${ic('globe', 18)}</span></span>`,
    `<span style="width:40px;height:40px;border-radius:20px 20px 8px 8px;background:var(--secondary-c);color:var(--on-secondary-c);display:grid;place-items:center">${ic('cloud', 20)}</span>`,
    `<span style="position:relative;width:40px;height:40px;display:grid;place-items:center;color:var(--on-primary-c)">${P.shape('cookie9', 40, 'var(--primary-c)', { style: 'position:absolute;inset:0' })}<span style="position:relative">${ic('code', 18)}</span></span>`,
    `<span style="width:40px;height:40px;border-radius:12px;background:var(--secondary-c);color:var(--on-secondary-c);display:grid;place-items:center">${ic('cloud', 20)}</span>`,
    `<span style="position:relative;width:40px;height:40px;display:grid;place-items:center;color:var(--on-lime)">${P.shape('clover4', 40, 'var(--lime)', { style: 'position:absolute;inset:0' })}<span style="position:relative">${ic('search', 18)}</span></span>`,
  ][i];

  /* ---------- 01 Splash ---------- */
  T.splash = () => `
    <div class="col" style="flex:1;align-items:center;justify-content:center;gap:32px">
      <div class="a-pop">${P.logoMark(220, { animated: true })}</div>
      <div class="col a-rise" style="${d(0.35)};align-items:center;gap:10px">${P.wordmark(72)}<span class="t-sup" style="font-size:17px">Network tools that feel alive</span></div>
      <div class="col a-fade" style="${d(0.6)};align-items:center;gap:10px;margin-top:24px">${P.wavyLinear(220, 0.62)}<span class="t-label">Starting monitors…</span></div>
    </div>`;

  /* ---------- 02 Ping (all hosts) ---------- */
  T.ping = () => main(`
    ${head('Ping', `<button class="btn tonal">${ic('pause', 18, 2.4)}Pause all</button><button class="btn pink lg">${ic('plus', 20, 2.6)}Add host</button>`, '6 hosts live · every 1 s · 0.6% loss overall')}
    <section style="flex:1;display:grid;grid-template-columns:repeat(3,minmax(0,1fr));grid-template-rows:repeat(2,minmax(0,1fr));gap:12px;margin-top:16px">
      ${D.hosts.map((h, i) => `
        <button class="card a-rise" style="${d(i * 0.05)};padding:18px 20px;display:flex;flex-direction:column;justify-content:space-between;text-align:left;${i === 1 ? 'background:var(--secondary-c);color:var(--on-secondary-c)' : ''}">
          <span class="row" style="gap:12px;width:100%">${hostLead(i)}<span class="col grow"><span class="t-title-lg ellip" style="font-size:19px">${h.name}</span><span class="ellip" style="font-size:13px;opacity:.8">${h.host}</span></span>
            ${P.shape('cookie9', 18, h.loss ? 'var(--lat-slow)' : 'var(--lat-fast)', { cls: 'a-spin-f' })}</span>
          <span class="row" style="align-items:flex-end;justify-content:space-between;width:100%">
            <span class="row" style="align-items:baseline;gap:4px"><span style="font-size:68px;font-weight:900;line-height:.9;letter-spacing:-.04em;font-variation-settings:'wdth' 120" data-tick="h${i}">${P.fmt(h.ms)}</span><span style="font-size:17px;font-weight:800">ms</span></span>
            ${h.loss ? `<span class="pill pink">${h.loss}% loss</span>` : `<span class="pill lime">${ic('check', 14, 3)}0% loss</span>`}
          </span>
          ${P.bars(h.spark, { h: 52, w: 9, gap: 5, max: Math.max(...h.spark.filter((v) => v != null)) * 1.25 })}
          <span class="row" style="gap:18px;font-size:13px;width:100%;opacity:.9"><span>Avg <b>${h.avg}</b></span><span>Max <b>${h.max}</b></span><span>Jitter <b>${h.jit}</b></span><span style="margin-left:auto">${h.sent} sent</span></span>
        </button>`).join('')}
    </section>`);
  T.ping.rail = 'ping';

  /* ---------- 03 Ping detail (list-detail) ---------- */
  T.pingDetail = () => {
    const s = D.single;
    return `
    <aside class="pane" style="width:340px;flex:none;margin:12px 0;padding:20px 12px;display:flex;flex-direction:column">
      <div class="row" style="justify-content:space-between;padding:0 4px 12px 12px"><span class="t-h2">Hosts</span><button class="icon-btn tonal" aria-label="Pause all">${ic('pause', 20, 2.4)}</button></div>
      <div class="seg high">${D.hosts.map((h, i) => `
        <button class="item a-rise-x${i === 1 ? ' sel' : ''}" style="${d(i * 0.04)};min-height:62px">
          <span class="lead">${hostLead(i)}</span><span class="txt"><span class="h">${h.name}</span><span class="s"${h.loss ? ' style="color:var(--lat-slow)"' : ''}>${h.loss ? h.loss + '% loss · ' : ''}${h.host}</span></span>
          <span class="v" data-tick="h${i}">${P.fmt(h.ms)}<small>ms</small></span></button>`).join('')}</div>
      <div style="flex:1"></div>
      <button class="btn pink lg" style="width:100%">${ic('plus', 20, 2.6)}Add host</button>
    </aside>
    ${main(`
      <header class="row" style="gap:8px;flex:none"><div class="col grow"><h1 class="t-hl" style="margin:0">${s.name}</h1><span class="t-sup">${s.host} · started 16:24 · 312 sent</span></div>
        <button class="icon-btn" aria-label="Ping settings">${ic('tune', 22)}</button><button class="icon-btn" aria-label="Share">${ic('share', 22)}</button><button class="icon-btn" aria-label="More">${ic('more', 22)}</button></header>
      <section class="row" style="gap:28px;margin-top:12px;align-items:center">
        <div style="position:relative;width:300px;height:280px;flex:none;display:grid;place-items:center">
          <div class="a-morph" aria-hidden="true" style="position:absolute;left:70px;top:20px;width:230px;height:240px;background:var(--secondary-c)"></div>
          <div class="a-breathe" style="position:relative;width:260px;height:260px">
            ${P.shape('cookie12', 260, 'var(--pink)', { cls: 'a-spin', style: 'position:absolute;inset:0' })}
            <div class="col" style="position:absolute;inset:0;align-items:center;justify-content:center;color:var(--on-pink)">
              <span class="row" style="gap:6px;font-size:15px;font-weight:700"><span class="live a-blink"></span>Live</span>
              <span class="row" style="align-items:baseline;gap:2px"><span class="t-hero" style="font-size:120px" data-tick="single">${s.ms}</span><span style="font-size:24px;font-weight:800">ms</span></span>
            </div>
          </div>
        </div>
        <div class="col grow" style="gap:14px">
          <span class="row" style="gap:8px"><span class="pill lime">${ic('check', 14, 3)}No loss</span><span class="pill lav">Jitter 5.8 ms</span><span class="pill soft">Every 1 s · 56 B</span></span>
          <div style="display:grid;grid-template-columns:repeat(2,1fr);gap:6px">
            ${[['Average', s.avg + ' ms', ''], ['Loss', '0%', 'color:var(--tertiary)'], ['Max', s.max + ' ms', 'color:var(--lat-slow)'], ['Min', '34 ms', '']].map(([k, v, st], i) => `
              <div class="stat a-rise" style="${d(0.1 + i * 0.05)};padding:14px 16px;border-radius:${['22px 6px 6px 6px', '6px 22px 6px 6px', '6px 6px 6px 22px', '6px 6px 22px 6px'][i]}"><span class="k" style="font-size:13px">${k}</span><span class="n" style="font-size:28px;${st}">${v}</span></div>`).join('')}
          </div>
        </div>
      </section>
      <section class="card a-rise" style="${d(0.2)};margin-top:16px;padding:16px 20px">
        <div class="row" style="justify-content:space-between"><span class="t-title">Last 60 pings</span><span class="row" style="gap:14px;font-size:12px;font-weight:600;color:var(--on-surface-var)"><span class="row" style="gap:5px"><span style="width:10px;height:10px;border-radius:5px;background:var(--lat-fast)"></span>&lt;10 ms</span><span class="row" style="gap:5px"><span style="width:10px;height:10px;border-radius:5px;background:var(--lat-mid)"></span>10–40</span><span class="row" style="gap:5px"><span style="width:10px;height:10px;border-radius:5px;background:var(--lat-slow)"></span>&gt;40</span></span></div>
        <div style="position:relative;margin-top:12px"><div aria-hidden="true" style="position:absolute;left:0;right:0;bottom:${Math.round((39 / 100) * 150)}px;border-top:2px dashed var(--outline-var)"></div>${P.bars([...s.spark, ...s.spark.slice().reverse()], { h: 150, max: 100, w: 8, gap: 4.8 })}</div>
      </section>
      <div style="flex:1"></div>
      <div class="row" style="gap:8px"><button class="chip">${ic('timer', 18)}Interval 1 s</button><button class="chip">Size 56 B</button><button class="chip">Timeout 2 s</button><button class="chip">${ic('bell', 18)}Alert on loss</button><span class="grow"></span><button class="btn lg pink">${ic('stop', 18)}Stop</button></div>
    `)}`;
  };
  T.pingDetail.rail = 'ping';

  /* ---------- 04 Network ---------- */
  T.network = () => {
    const n = D.net;
    const rows = [['Local IPv4', n.ipv4, 1], ['Subnet', n.subnet, 1], ['Gateway', n.gateway, 1], ['DNS 1', n.dns1, 1], ['DNS 2', '—', 0], ['MAC address', 'Hidden by Android', 0], ['IPv6', 'Not assigned', 0]];
    return main(`
      ${head('Network', `<button class="btn tonal">${ic('refresh', 18, 2.4)}Refresh</button>`, 'Updated just now')}
      <section class="row" style="gap:16px;margin-top:16px;align-items:stretch;flex:1">
        <div class="col" style="width:540px;flex:none;gap:12px">
          <div class="a-rise" style="position:relative;height:250px;border-radius:32px;background:var(--pink);color:var(--on-pink);overflow:hidden;padding:24px 28px">
            ${P.shape('cookie12', 280, 'rgba(255,255,255,.28)', { cls: 'a-spin', style: 'position:absolute;right:-60px;top:-70px' })}
            <div class="row" style="position:relative;gap:8px;font-size:15px;font-weight:700">${ic('wifi', 20, 2.6)}Connected · ${n.kind}</div>
            <div style="position:relative;font-size:84px;font-weight:900;letter-spacing:-.03em;line-height:1;margin-top:18px;font-variation-settings:'wdth' 125">${n.ssid}</div>
            <div class="row" style="position:relative;gap:8px;margin-top:22px"><span class="pill" style="background:var(--on-pink);color:var(--pink)">${ic('signal', 16, 2.6)}Good signal</span><span class="pill" style="background:rgba(59,7,32,.12);color:var(--on-pink)">Channel 6</span></div>
          </div>
          <div class="row" style="gap:12px">
            <div class="card a-rise" style="${d(0.08)};flex:1;padding:18px 20px;display:flex;align-items:center;gap:16px">
              <span aria-hidden="true" class="row" style="gap:5px;align-items:flex-end;height:44px">${[14, 24, 34, 44].map((hh, i) => `<span class="a-grow-y" style="${d(0.2 + i * 0.06)};width:10px;height:${hh}px;border-radius:5px;background:${i < 3 ? 'var(--lat-fast)' : 'var(--surface-highest)'}"></span>`).join('')}</span>
              <span class="col"><span class="t-label">Signal</span><span style="font-size:30px;font-weight:900;font-variation-settings:'wdth' 115">${n.signal} dBm</span></span>
            </div>
            <div class="card a-rise" style="${d(0.12)};flex:1;padding:18px 20px;display:flex;align-items:center;gap:16px">
              <span style="position:relative;width:48px;height:48px;display:grid;place-items:center;color:var(--on-lav)">${P.shape('sunny', 48, 'var(--lav)', { cls: 'a-spin', style: 'position:absolute;inset:0' })}<span style="position:relative">${ic('gauge', 22)}</span></span>
              <span class="col"><span class="t-label">Link speed</span><span style="font-size:30px;font-weight:900;font-variation-settings:'wdth' 115">${n.link} Mb/s</span></span>
            </div>
          </div>
          <div class="a-rise" style="${d(0.16)};flex:1;border-radius:28px;background:var(--lime);color:var(--on-lime);padding:20px 24px;display:flex;align-items:center;gap:18px">
            <span style="position:relative;width:64px;height:64px;display:grid;place-items:center">${P.shape('clover4', 64, 'var(--on-lime)', { cls: 'a-wobble', style: 'position:absolute;inset:0' })}<span style="position:relative;color:var(--lime)">${ic('lan', 28)}</span></span>
            <span class="col grow"><span style="font-size:20px;font-weight:800">Who's on this network?</span><span style="font-size:14px">Last scan found 3 devices · Nov 11, 16:26</span></span>
            <button class="btn lg" style="background:var(--on-lime);color:var(--lime)">Scan network</button>
          </div>
        </div>
        <div class="seg grow">${rows.map(([k, v, cp], i) => `
          <div class="item a-rise" style="${d(0.05 + i * 0.04)};flex:1;padding:6px 12px 6px 20px">
            <span class="txt"><span class="s">${k}</span><span class="h" style="font-size:20px;${cp ? '' : 'color:var(--on-surface-var);font-weight:500'}">${v}</span></span>
            ${cp ? `<button class="icon-btn" aria-label="Copy ${k}">${ic('copy', 22)}</button>` : k.startsWith('MAC') ? `<button class="icon-btn" aria-label="Why">${ic('info', 22)}</button>` : ''}
          </div>`).join('')}</div>
      </section>`);
  };
  T.network.rail = 'net';

  /* ---------- 05 Tools ---------- */
  T.tools = () => main(`
    ${head('Tools', `<button class="btn tonal">${ic('settings', 18)}Settings</button>`, '8 tools · tap to open, long-press to pin')}
    <section style="flex:1;display:grid;grid-template-columns:repeat(4,minmax(0,1fr));grid-template-rows:repeat(2,minmax(0,1fr));gap:12px;margin-top:16px">
      ${P.TOOLS.map((t, i) => {
        const hot = t.k === 'monitor';
        return `<button class="a-rise" style="${d(i * 0.04)};border-radius:${hot ? 36 : 28}px;padding:22px;display:flex;flex-direction:column;justify-content:space-between;background:${hot ? 'var(--pink)' : 'var(--surface-c)'};color:${hot ? 'var(--on-pink)' : 'inherit'}">
          <span class="row" style="justify-content:space-between;width:100%;align-items:flex-start">${hot ? `<span style="position:relative;width:72px;height:72px;display:grid;place-items:center;color:var(--pink)">${P.shape('diamond', 72, 'var(--on-pink)', { style: 'position:absolute;inset:0' })}<span style="position:relative">${ic(t.icon, 32, 2.2)}</span></span>` : P.toolBadge(t, 72, 32)}
            ${hot ? `<span class="row" style="gap:6px;font-size:13px;font-weight:800"><span class="live a-blink"></span>LIVE</span>` : `<span style="color:var(--on-surface-var)">${ic('chevR', 22)}</span>`}</span>
          <span class="col" style="gap:2px"><span style="font-size:28px;font-weight:800;font-variation-settings:'wdth' 115">${t.name}</span><span style="font-size:15px;${hot ? '' : 'color:var(--on-surface-var)'}">${t.last}</span></span>
        </button>`;
      }).join('')}
    </section>`);
  T.tools.rail = 'tools';

  /* ---------- 06 Traceroute ---------- */
  T.trace = () => {
    const rows = D.hops.slice(0, 8);
    const hopRow = (h, i) => `<div class="item a-rise-x" style="${d(0.05 + i * 0.03)};min-height:46px;padding:4px 16px">
      <span style="width:24px;font-size:13px;font-weight:700;color:var(--on-surface-var)">${h.n}</span>
      <span style="width:12px;height:12px;border-radius:50%;background:${P.latColor(h.ms)};flex:none"></span>
      <span class="txt"><span class="h" style="font-size:15px">${h.host}</span><span class="s" style="font-size:12px">${h.ip ? h.ip + ' · ' : ''}${h.probes.join(' / ')} ms</span></span>
      <span class="pill out" style="height:24px;font-size:11px;padding:0 8px">${h.zone}</span>
      <span class="v" style="font-size:18px;width:48px;text-align:right">${h.ms}</span></div>`;
    return toolFrame('trace', `
      <header class="row" style="gap:12px;flex:none"><h1 class="t-h2" style="margin:0">Traceroute</h1><label class="field grow" style="height:52px">${ic('search', 22)}<input value="github.com" aria-label="Target"><span class="aux">20.205.243.166 · max 30 hops · 3 probes</span></label><button class="btn pink lg">${ic('refresh', 18, 2.4)}Run again</button></header>
      <section class="row" style="gap:16px;margin-top:16px;align-items:stretch;flex:1;min-height:0">
        <div class="seg grow" style="align-self:flex-start">
          ${rows.map(hopRow).join('')}
          <div class="item a-rise-x" style="${d(0.3)};min-height:44px;padding:4px 16px;color:var(--on-surface-var)"><span style="width:28px;font-size:13px;font-weight:700">09</span><span style="width:12px;height:12px;border-radius:50%;border:2px dashed var(--outline);flex:none;box-sizing:border-box"></span><span class="txt"><span class="h" style="font-size:15px;font-weight:500">No reply · 09–10</span></span><span class="s">probes timed out</span></div>
          <div class="item a-rise-x" style="${d(0.33)};min-height:44px;padding:4px 16px"><span style="width:28px;font-size:13px;font-weight:700;color:var(--on-surface-var)">11</span><span style="width:12px;height:12px;border-radius:50%;background:var(--lat-slow);flex:none"></span><span class="txt"><span class="h" style="font-size:15px">Transit · hops 11–20</span></span><span class="pill pink" style="height:26px">+55 ms jump</span>${ic('chevD', 20)}</div>
          <div class="item a-rise-x sel" style="${d(0.36)};min-height:52px;padding:4px 16px"><span style="width:28px;font-size:13px;font-weight:700">21</span>${P.shape('cookie9', 18, 'var(--pink)', { cls: 'a-spin-f' })}<span class="txt"><span class="h" style="font-size:16px">github.com</span></span><span class="s" style="width:130px">20.205.243.166</span><span class="pill" style="height:24px;font-size:11px;padding:0 8px;background:var(--on-secondary-c);color:var(--secondary-c)">SG</span><span class="v" style="font-size:19px;width:52px;text-align:right">56</span></div>
        </div>
        <div class="col" style="width:300px;flex:none;gap:12px">
          <div class="card a-rise" style="padding:18px 20px">
            <span class="t-label">Destination reached</span>
            <div class="row" style="align-items:baseline;gap:6px;margin-top:4px"><span class="t-display">56</span><span style="font-size:16px;font-weight:700">ms</span></div>
            <div class="row" style="gap:6px;margin-top:12px;flex-wrap:wrap"><span class="pill lime">21 hops</span><span class="pill lav">BD → SG</span><span class="pill out">10 timeouts</span></div>
          </div>
          <div class="card a-rise" style="${d(0.1)};padding:14px 16px 8px"><span class="t-label">Route</span><div style="margin-top:6px">${P.hopRail(268)}</div></div>
          <div class="a-rise" style="${d(0.15)};border-radius:28px;background:var(--primary-c);color:var(--on-primary-c);padding:16px 18px">
            <span class="row" style="gap:8px;font-weight:800;font-size:15px">${ic('info', 20)}Biggest jump</span>
            <p style="margin:6px 0 0;font-size:14px;line-height:1.45">Hop 08 → 11 adds <b>55 ms</b>. That is where traffic leaves your ISP's network, so it is outside your control.</p>
          </div>
          <div class="row" style="gap:8px;margin-top:auto"><button class="btn tonal" style="flex:1">${ic('copy', 18)}Copy</button><button class="btn tonal" style="flex:1">${ic('export', 18)}Save</button></div>
        </div>
      </section>`);
  };
  T.trace.rail = 'tools';

  /* ---------- 07 Port scan ---------- */
  T.ports = () => {
    const open = [5, 20], filt = [161];
    const cells = [...Array(256)].map((_, i) => `<span class="a-cell" style="animation-delay:${(i * 0.004).toFixed(3)}s;width:21px;height:21px;border-radius:6px;box-sizing:border-box;${open.includes(i) ? 'background:var(--pink)' : filt.includes(i) ? 'background:var(--lav)' : 'border:1.5px solid var(--outline-var)'}"></span>`).join('');
    return toolFrame('ports', `
      <header class="row" style="gap:12px;flex:none"><h1 class="t-h2 grow" style="margin:0">Port scan</h1><button class="btn pink lg">${ic('play', 18)}Scan</button></header>
      <div class="row" style="gap:12px;margin-top:12px"><label class="field grow">${ic('search', 22)}<input value="scanme.nmap.org" aria-label="Target"><span class="aux">45.33.32.156</span></label>
        <div class="group" style="width:340px;flex:none"><button>Common</button><button class="on">1–1024</button><button>Custom</button></div></div>
      <section style="display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-top:16px">
        ${[['circle', 'var(--surface-highest)', 'var(--on-surface)', 'Scanned', '1024', ''], ['cookie9', 'var(--pink)', 'var(--on-pink)', 'Open', '2', 'a-spin-f'], ['clover4', 'var(--lav)', 'var(--on-lav)', 'Filtered', '1', 'a-wobble'], ['square', 'var(--lime)', 'var(--on-lime)', 'Time', '4.9 s', '']].map(([sh, f, on, k, v, cl], i) => `
          <div class="card a-rise" style="${d(i * 0.05)};padding:14px 16px;display:flex;align-items:center;gap:14px">
            <span style="position:relative;width:56px;height:56px;display:grid;place-items:center;flex:none;color:${on}">${P.shape(sh, 56, f, { cls: cl, style: 'position:absolute;inset:0' })}<span style="position:relative">${ic(['grid', 'port', 'shield', 'timer'][i], 24)}</span></span>
            <span class="col"><span class="t-label">${k}</span><span style="font-size:30px;font-weight:900;line-height:1.05;font-variation-settings:'wdth' 115">${v}</span></span></div>`).join('')}
      </section>
      <section class="card a-rise" style="${d(0.2)};margin-top:16px;padding:16px 18px">
          <div class="row" style="justify-content:space-between"><span class="t-title">Port map · 1–1024</span><span class="row" style="gap:16px;font-size:12px;font-weight:600;color:var(--on-surface-var)"><span class="row" style="gap:5px"><span style="width:10px;height:10px;border-radius:3px;background:var(--pink)"></span>Open</span><span class="row" style="gap:5px"><span style="width:10px;height:10px;border-radius:3px;background:var(--lav)"></span>Filtered</span><span class="row" style="gap:5px"><span style="width:10px;height:10px;border-radius:3px;border:1.5px solid var(--outline-var)"></span>Closed</span><span>· each cell = 4 ports · 128 connections</span></span></div>
          <div style="display:grid;grid-template-columns:repeat(32,21px);gap:4px;margin-top:12px">${cells}</div>
      </section>
      <div class="seg" style="margin-top:12px">${D.ports.range.map((p, i) => `
          <div class="item a-rise" style="${d(0.25 + i * 0.05)};min-height:58px;padding:8px 16px">
            <span style="width:72px;font-size:26px;font-weight:900;line-height:1;font-variation-settings:'wdth' 110">${p.port}</span>
            <span class="h" style="width:110px;flex:none">${p.svc}</span><span class="s grow">${p.banner}</span>
            <span class="pill ${p.state === 'open' ? 'pink' : 'out'}" style="height:28px">${p.state === 'open' ? 'Open' : 'Filtered'}</span></div>`).join('')}</div>`);
  };
  T.ports.rail = 'tools';

  /* ---------- 08 Speed test ---------- */
  T.speed = () => toolFrame('speed', `
    <header class="row" style="gap:12px;flex:none"><h1 class="t-h2 grow" style="margin:0">Speed test</h1><button class="btn outline">${ic('server', 18)}Cloudflare · DAC · anycast</button><button class="btn tonal">${ic('stop', 16)}Cancel</button></header>
    <section class="row" style="gap:20px;margin-top:16px;align-items:stretch;flex:1">
      <div class="col grow" style="align-items:center;gap:14px">
        <div class="group" style="width:100%"><button class="done">${ic('check', 18, 2.8)}Ping 37 ms</button><button class="on">${ic('down', 18, 2.8)}Download</button><button>${ic('up', 18)}Upload</button></div>
        ${P.wavyGauge(400, 0.36, `<span style="font-size:16px;font-weight:600;color:var(--on-surface-var)">Download</span><span style="font-size:132px;font-weight:900;line-height:1;letter-spacing:-.04em;font-variation-settings:'wdth' 125" data-tick="dl">9.4</span><span style="font-size:20px;font-weight:700;color:var(--primary)">Mbps</span>`)}
        <div style="width:100%"><div class="row" style="justify-content:space-between;font-size:13px;color:var(--on-surface-var)"><span>Measuring download · log scale 1–500 Mbps</span><span data-tick="secs">6.2 s</span></div><div style="margin-top:6px">${P.wavyLinear(470, 0.62)}</div></div>
      </div>
      <div class="col" style="width:300px;flex:none;gap:12px">
        <div style="display:grid;grid-template-columns:repeat(2,1fr);gap:12px">
          ${[['clover4', 'var(--lime)', 'var(--on-lime)', 'Ping', '37', 'a-wobble'], ['sunny', 'var(--lav)', 'var(--on-lav)', 'Jitter', '27', 'a-spin']].map(([sh, f, on, k, v, cl], i) => `
            <div class="a-pop" style="${d(0.2 + i * 0.1)};position:relative;aspect-ratio:1;display:grid;place-items:center">${P.shape(sh, 140, f, { cls: cl, style: 'position:absolute;inset:0;width:100%;height:100%' })}
              <span class="col" style="position:relative;align-items:center;color:${on}"><span style="font-size:13px;font-weight:700">${k}</span><span style="font-size:40px;font-weight:900;line-height:1;font-variation-settings:'wdth' 120">${v}</span><span style="font-size:12px;font-weight:700">ms</span></span></div>`).join('')}
        </div>
        <div class="card" style="padding:14px 18px;display:flex;align-items:center;gap:12px;border:2px dashed var(--outline-var);background:transparent"><span style="color:var(--on-surface-var)">${ic('up', 22)}</span><span class="col grow"><span class="t-title">Upload</span><span class="t-sup">Starts after download</span></span><span style="font-size:24px;font-weight:900;color:var(--outline)">—</span></div>
        <h2 class="t-title" style="margin:6px 0 0 4px">Past results</h2>
        <div class="seg">${[['16:34', '9.4', '7.1', '37'], ['16:33', '9.2', '7.0', '39'], ['16:32', '8.3', '6.4', '42']].map(([t, dn, up, pg], i) => `
          <div class="item a-rise" style="${d(0.3 + i * 0.05)};min-height:56px"><span class="txt"><span class="h" style="font-size:15px">Today ${t}</span><span class="s">Cloudflare · DAC · ${pg} ms</span></span><span class="col" style="align-items:flex-end"><span style="font-size:16px;font-weight:800">${dn} ↓</span><span class="s">${up} ↑</span></span></div>`).join('')}</div>
      </div>
    </section>`);
  T.speed.rail = 'tools';

  /* ---------- 09 Packet loss ---------- */
  T.loss = () => {
    const lost = [5, 51];
    const rtt = [...Array(89)].map((_, i) => (lost.includes(i) ? null : +(11 + Math.abs(Math.sin(i * 1.7)) * 5 + (i % 23 === 7 ? 18 : 0)).toFixed(1)));
    const cells = [...Array(300)].map((_, i) => `<span${i < 89 ? ` class="a-cell" style="animation-delay:${(i * 0.005).toFixed(3)}s;` : ' style="'}width:10px;height:10px;border-radius:3px;background:${i >= 89 ? 'var(--surface-highest)' : lost.includes(i) ? 'var(--lat-slow)' : 'var(--lat-fast)'}"></span>`).join('');
    return toolFrame('loss', `
      <header class="row" style="gap:12px;flex:none"><h1 class="t-h2" style="margin:0">Packet loss</h1><label class="field grow" style="height:52px">${ic('search', 22)}<input value="1.1.1.1" aria-label="Target"></label><button class="chip">${ic('timer', 18)}5 min</button><button class="chip">1 / s</button><button class="btn pink lg">${ic('stop', 16)}Stop</button></header>
      <section class="row" style="gap:24px;margin-top:18px;align-items:center">
        <div class="a-pop" style="position:relative;width:230px;height:230px;flex:none;display:grid;place-items:center">${P.shape('burst', 230, 'var(--pink)', { cls: 'a-spin', style: 'position:absolute;inset:0' })}
          <span class="col" style="position:relative;align-items:center;color:var(--on-pink)"><span style="font-size:15px;font-weight:700">Loss</span><span style="font-size:56px;font-weight:900;line-height:.95;letter-spacing:-.03em;font-variation-settings:'wdth' 100">2.2%</span></span></div>
        <div class="col grow" style="gap:14px">
          <div class="row" style="gap:10px"><span class="pill lav">Unstable</span><span class="t-sup">Verdict so far</span></div>
          <p style="margin:0;font-size:18px;line-height:1.45;max-width:460px">Drops are isolated single packets, which points to mild congestion along the path rather than a broken link.</p>
          <div class="stats" style="grid-template-columns:repeat(4,1fr)">
            <div class="stat"><span class="k">Sent</span><span class="n" style="font-size:26px">89</span></div><div class="stat"><span class="k">Lost</span><span class="n" style="font-size:26px;color:var(--lat-slow)">2</span></div>
            <div class="stat"><span class="k">Late &gt;150 ms</span><span class="n" style="font-size:26px">0</span></div><div class="stat"><span class="k">Longest burst</span><span class="n" style="font-size:26px">1</span></div>
          </div>
        </div>
      </section>
      <section style="margin-top:18px"><div class="row" style="justify-content:space-between;font-size:13px;color:var(--on-surface-var)"><span>Elapsed 1:29 of 5:00</span><span>30%</span></div><div style="margin-top:6px">${P.wavyLinear(828, 0.3)}</div></section>
      <section class="card a-rise" style="${d(0.2)};margin-top:14px;padding:16px 18px">
        <div class="row" style="justify-content:space-between"><span class="t-title">Timeline · 1 cell = 1 packet</span><span class="row" style="gap:12px;font-size:12px;font-weight:600;color:var(--on-surface-var)"><span class="row" style="gap:5px"><span style="width:10px;height:10px;border-radius:3px;background:var(--lat-fast)"></span>OK</span><span class="row" style="gap:5px"><span style="width:10px;height:10px;border-radius:3px;background:var(--lat-mid)"></span>Late</span><span class="row" style="gap:5px"><span style="width:10px;height:10px;border-radius:3px;background:var(--lat-slow)"></span>Lost</span></span></div>
        <div style="display:grid;grid-template-columns:repeat(60,10px);gap:3px;margin-top:12px">${cells}</div>
      </section>
      <section class="card a-rise" style="${d(0.25)};margin-top:12px;padding:16px 18px">
        <div class="row" style="justify-content:space-between"><span class="t-title">Round-trip time</span><span class="t-label">avg 13 ms · max 34 ms</span></div>
        <div style="margin-top:12px">${P.bars(rtt, { h: 70, w: 5, gap: 3.9, max: 36 })}</div>
      </section>
      <div class="row" style="gap:8px;margin-top:auto"><button class="btn outline">${ic('export', 18)}Export CSV</button><button class="btn tonal">${ic('bell', 18)}Alert on loss</button><button class="btn outline">${ic('loss', 18)}Compare with 8.8.8.8</button></div>`);
  };
  T.loss.rail = 'tools';

  /* ---------- 10 LAN scan ---------- */
  T.lan = () => toolFrame('lan', `
    <header class="row" style="gap:12px;flex:none"><div class="col grow"><h1 class="t-h2" style="margin:0">LAN scan</h1><span class="t-sup">192.168.0.0/24 · 254 hosts · ICMP + TCP</span></div><button class="btn pink lg">${ic('refresh', 18, 2.4)}Scan again</button></header>
    <section class="card a-rise" style="margin-top:14px;padding:16px 20px;display:flex;align-items:center;gap:18px">
      <div style="position:relative;width:76px;height:76px;display:grid;place-items:center;flex:none">${P.shape('clover4', 76, 'var(--lime)', { cls: 'a-wobble', style: 'position:absolute;inset:0' })}<span style="position:relative;font-size:38px;font-weight:900;color:var(--on-lime)">3</span></div>
      <div class="col grow" style="gap:6px"><span class="t-title-lg">Devices found</span><span class="t-sup">Scan complete · 254 of 254 hosts · 21.6 s</span></div>
      <div style="width:300px">${P.wavyLinear(300, 1, { color: 'var(--tertiary)' })}</div>
    </section>
    <section class="row" style="gap:16px;margin-top:14px;align-items:stretch;flex:1">
      <div class="col" style="width:330px;flex:none;gap:10px">
        <div class="chips"><button class="chip sm sel">${ic('check', 16, 2.8)}All 3</button><button class="chip sm">Router</button><button class="chip sm">Phones</button><button class="chip sm">Unknown</button></div>
        <div class="seg">
          <button class="item sel a-rise" style="min-height:68px"><span class="lead"><span style="width:40px;height:40px;border-radius:50%;background:var(--lav);color:var(--on-lav);display:grid;place-items:center">${ic('router', 20)}</span></span><span class="txt"><span class="h">Router</span><span class="s">192.168.0.1 · gateway</span></span><span class="v">3.9<small>ms</small></span></button>
          <button class="item a-rise" style="${d(0.05)};min-height:68px"><span class="lead"><span style="width:40px;height:40px;border-radius:12px;background:var(--tertiary-c);color:var(--on-tertiary-c);display:grid;place-items:center">${ic('phone', 20)}</span></span><span class="txt"><span class="h">This device</span><span class="s">192.168.0.31 · tablet</span></span><span class="v">0.1<small>ms</small></span></button>
          <button class="item a-rise" style="${d(0.1)};min-height:68px"><span class="lead"><span style="width:40px;height:40px;border-radius:50%;border:2px dashed var(--outline);display:grid;place-items:center;color:var(--on-surface-var)">${ic('help', 20)}</span></span><span class="txt"><span class="h">Unknown device</span><span class="s">192.168.0.43</span></span><span class="v">30<small>ms</small></span></button>
        </div>
      </div>
      <div class="a-rise grow" style="${d(0.1)};border-radius:32px;background:var(--secondary-c);color:var(--on-secondary-c);padding:22px 26px;display:flex;flex-direction:column">
        <div class="row" style="gap:16px"><span style="position:relative;width:64px;height:64px;display:grid;place-items:center;color:var(--on-lav)">${P.shape('cookie9', 64, 'var(--lav)', { cls: 'a-spin-f', style: 'position:absolute;inset:0' })}<span style="position:relative">${ic('router', 28)}</span></span>
          <span class="col grow"><span style="font-size:30px;font-weight:900;font-variation-settings:'wdth' 115">192.168.0.1</span><span style="font-size:14px;opacity:.85">Router · gateway · RTT 3.9 ms</span></span></div>
        <div style="display:grid;grid-template-columns:repeat(2,1fr);gap:16px 24px;margin-top:22px;font-size:15px">
          ${[['Hostname', '—'], ['Vendor', '—'], ['MAC', 'Hidden by Android'], ['First seen', 'Nov 8, 15:05']].map(([k, v]) => `<span class="col"><span style="font-size:13px;opacity:.8">${k}</span><span style="font-weight:700;font-size:17px">${v}</span></span>`).join('')}
        </div>
        <span style="font-size:13px;opacity:.8;margin-top:20px">Open ports</span>
        <div class="row" style="gap:8px;margin-top:8px">${[['53', 'DNS'], ['80', 'HTTP'], ['443', 'HTTPS'], ['1900', 'UPnP']].map(([p, n]) => `<span class="pill" style="height:34px;background:var(--surface);color:var(--on-surface)"><b>${p}</b><span style="font-weight:500;opacity:.8">${n}</span></span>`).join('')}</div>
        <div class="row" style="gap:8px;margin-top:auto"><button class="btn lg pink">${ic('pulse', 18)}Ping</button><button class="btn lg" style="background:var(--surface);color:var(--on-surface)">${ic('port', 18)}Scan ports</button><button class="btn lg" style="color:var(--on-secondary-c);opacity:.5" disabled>${ic('power', 18)}Wake on LAN</button></div>
      </div>
    </section>`);
  T.lan.rail = 'tools';

  /* ---------- 11 Geo IP ---------- */
  T.geo = () => toolFrame('geo', `
    <header class="row" style="gap:12px;flex:none"><h1 class="t-h2" style="margin:0">Geo IP</h1><label class="field grow" style="height:52px">${ic('search', 22)}<input value="github.com" aria-label="Lookup"><span class="aux">→ 20.205.243.166</span></label><button class="btn tonal">My IP</button><button class="btn pink lg">Locate</button></header>
    <section class="row" style="gap:16px;margin-top:16px;align-items:stretch;flex:1">
      <div class="a-rise">${P.geoMap(450, 668, [250, 0, 520, 640])}</div>
      <div class="col grow" style="gap:12px">
        <div class="a-rise" style="${d(0.08)};position:relative;border-radius:32px;background:var(--pink);color:var(--on-pink);padding:20px 22px;overflow:hidden">
          ${P.shape('cookie12', 170, 'rgba(255,255,255,.28)', { cls: 'a-spin', style: 'position:absolute;right:-40px;top:-50px' })}
          <span style="position:relative;font-size:13px;font-weight:700">Located in</span>
          <div style="position:relative;font-size:50px;font-weight:900;line-height:1;margin-top:4px;font-variation-settings:'wdth' 125">Singapore</div>
          <span style="position:relative;font-size:14px">SG · Asia/Singapore · UTC+8</span>
        </div>
        <div class="row" style="gap:6px"><span class="pill lime">2,887 km</span><span class="pill lav">55 ms</span><span class="pill soft">19 hops</span></div>
        <div class="seg">${[['IP', '20.205.243.166'], ['City', 'Singapore, Central Singapore'], ['Org', 'Microsoft Azure Cloud (southeastasia)'], ['ASN', 'AS8075'], ['Coordinates', '1.2830 N, 103.8330 E'], ['Postal', '168812'], ['Hosting', 'Yes · datacenter']].map(([k, v], i) => `
          <div class="item a-rise" style="${d(0.1 + i * 0.03)};min-height:42px;padding:4px 16px"><span class="s" style="width:90px">${k}</span><span class="h ellip" style="font-size:14px;flex:1;text-align:right">${v}</span></div>`).join('')}</div>
        <div class="row" style="gap:8px;margin-top:auto"><button class="btn tonal" style="flex:1">${ic('pulse', 18)}Ping this</button><button class="btn pink" style="flex:1">${ic('route', 18)}Trace route</button></div>
        <span class="t-label" style="font-weight:500">Data: ip-api.com · map tiles must carry their own attribution</span>
      </div>
    </section>`);
  T.geo.rail = 'tools';

  /* ---------- 12 Monitor ---------- */
  T.monitor = () => toolFrame('monitor', `
    <header class="row" style="gap:12px;flex:none"><h1 class="t-h2" style="margin:0">Monitor</h1>
      <span class="row" style="gap:8px;padding:0 6px 0 14px;height:44px;border-radius:22px;background:var(--surface-c);font-size:14px;font-weight:600"><span class="live a-blink" style="color:var(--tertiary)"></span>Running · 6 targets<button class="btn sm tonal">${ic('pause', 14, 2.6)}Pause</button></span>
      <span class="grow"></span><div class="group sm" style="width:220px"><button class="on">24 h</button><button>7 d</button><button>30 d</button></div><button class="btn pink lg">${ic('plus', 18, 2.6)}Add target</button></header>
    <section class="row" style="gap:12px;margin-top:16px;align-items:stretch">
      <div class="a-pop" style="position:relative;width:150px;height:150px;flex:none;display:grid;place-items:center">${P.shape('cookie12', 150, 'var(--lime)', { cls: 'a-spin', style: 'position:absolute;inset:0' })}<span class="col" style="position:relative;align-items:center;color:var(--on-lime)"><span style="font-size:12px;font-weight:700">Uptime 24h</span><span style="font-size:36px;font-weight:900;line-height:1;font-variation-settings:'wdth' 105">100%</span></span></div>
      ${[['Avg latency', '42 ms', ''], ['Incidents', '0', 'color:var(--tertiary)'], ['Checks', '13', '']].map(([k, v, st], i) => `<div class="card a-rise" style="${d(0.05 + i * 0.05)};flex:1;padding:18px 20px;display:flex;flex-direction:column;justify-content:space-between"><span class="t-label">${k}</span><span style="font-size:44px;font-weight:900;font-variation-settings:'wdth' 115;${st}">${v}</span></div>`).join('')}
    </section>
    <section class="row" style="gap:16px;margin-top:14px;align-items:stretch;flex:1">
      <div class="seg grow">${D.monitor.map((m, i) => `
        <button class="item a-rise" style="${d(0.15 + i * 0.04)};flex:1;min-height:0;gap:16px">
          <span class="txt" style="flex:none;width:160px"><span class="h">${m.host}</span><span class="s">${m.name}</span></span>
          <span aria-hidden="true" style="flex:1;display:flex;gap:3px;height:26px">${[...Array(36)].map((_, j) => `<span style="flex:1;border-radius:3px;background:var(--lat-fast);opacity:${j === 35 ? 1 : 0.45}"></span>`).join('')}</span>
          <span class="s" style="width:48px;text-align:right">${m.up}%</span><span class="v" style="width:56px;text-align:right">${m.ms}<small>ms</small></span>
        </button>`).join('')}</div>
      <aside class="card" style="width:250px;flex:none;padding:20px;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;gap:14px">
        <span style="position:relative;width:96px;height:96px;display:grid;place-items:center;color:var(--on-lav)">${P.shape('flower', 96, 'var(--lav)', { cls: 'a-spin', style: 'position:absolute;inset:0' })}<span style="position:relative">${ic('check', 40, 2.6)}</span></span>
        <span class="t-title-lg">No incidents</span><span class="t-sup">Outages, loss and latency spikes show up here, with a notification if you turn alerts on.</span>
      </aside>
    </section>`);
  T.monitor.rail = 'tools';

  /* ---------- 13 History (list-detail) ---------- */
  T.history = () => {
    const today = D.history.filter((h) => h.day === 'Today');
    return `${P.rail('history')}
    <aside class="pane" style="width:420px;flex:none;margin:12px 0;padding:20px 12px;display:flex;flex-direction:column;overflow:hidden">
      <div class="row" style="justify-content:space-between;padding:0 4px 10px 12px"><span class="t-h2">History</span><button class="icon-btn" aria-label="Export">${ic('export', 22)}</button></div>
      <label class="field" style="height:48px;margin:0 4px;background:var(--surface-highest)">${ic('search', 20)}<input value="" placeholder="Filter by name or host" aria-label="Filter" style="font-size:15px;font-weight:500"></label>
      <div class="chips" style="padding:10px 4px 0"><button class="chip sm sel">${ic('check', 16, 2.8)}All</button><button class="chip sm">Ping</button><button class="chip sm">Trace</button><button class="chip sm">Speed</button><button class="chip sm">Ports</button><button class="chip sm">LAN</button></div>
      <h2 class="t-label" style="margin:14px 0 8px 12px;font-size:13px">Today · ${today.length} runs</h2>
      <div class="seg high">${today.slice(0, 8).map((h, i) => P.historyItem(h, i, i === 6)).join('')}</div>
    </aside>
    ${main(`
      <header class="row" style="gap:16px;flex:none">
        <span style="position:relative;width:64px;height:64px;display:grid;place-items:center;color:var(--on-lav)">${P.shape('arch', 64, 'var(--lav)', { style: 'position:absolute;inset:0' })}<span style="position:relative">${ic('route', 28)}</span></span>
        <div class="col grow"><h1 class="t-hl" style="margin:0">github.com</h1><span class="t-sup">Traceroute · Today 16:30 · from AUT-SYS Wi-Fi</span></div>
        <button class="icon-btn" aria-label="Share">${ic('share', 22)}</button><button class="icon-btn" aria-label="Delete">${ic('trash', 22)}</button></header>
      <section class="row" style="gap:12px;margin-top:20px">
        ${[['56 ms', 'Total', 'var(--pink)', 'var(--on-pink)'], ['21', 'Hops', 'var(--lime)', 'var(--on-lime)'], ['BD → SG', 'Route', 'var(--lav)', 'var(--on-lav)'], ['10', 'Timeouts', 'var(--surface-high)', 'var(--on-surface)']].map(([v, k, f, on], i) => `
          <div class="a-rise" style="${d(i * 0.05)};flex:1;border-radius:${i === 0 ? '28px 8px 8px 28px' : i === 3 ? '8px 28px 28px 8px' : '8px'};background:${f};color:${on};padding:16px 18px"><span style="font-size:13px;font-weight:700">${k}</span><div style="font-size:34px;font-weight:900;line-height:1.05;white-space:nowrap;font-variation-settings:'wdth' 110">${v}</div></div>`).join('')}
      </section>
      <section class="card a-rise" style="${d(0.15)};margin-top:12px;padding:16px 20px 10px"><span class="t-label">Route</span><div style="margin-top:6px">${P.hopRail(640)}</div></section>
      <h2 class="t-title" style="margin:18px 0 8px 4px;font-weight:700">Highlights</h2>
      <div class="seg">
        <div class="item a-rise" style="${d(0.2)}"><span class="lead" style="color:var(--on-primary-c)">${P.shape('diamond', 38, 'var(--primary-c)', { style: 'position:absolute;inset:1px' })}<span style="position:relative;font-weight:800;font-size:13px">11</span></span><span class="txt"><span class="h">Biggest jump: hop 08 → 11</span><span class="s">Traffic leaves your ISP here</span></span><span class="pill pink">+55 ms</span></div>
        <div class="item a-rise" style="${d(0.24)}"><span class="lead"><span style="width:38px;height:38px;border-radius:50%;border:2px dashed var(--outline);display:grid;place-items:center;font-size:11px;font-weight:800;color:var(--on-surface-var)">9·10</span></span><span class="txt"><span class="h">2 hops didn't reply</span><span class="s">Common for routers that drop ICMP</span></span></div>
      </div>
      <div class="row" style="gap:8px;margin-top:auto"><button class="btn lg pink">${ic('refresh', 18, 2.4)}Run again</button><button class="btn lg tonal">${ic('copy', 18)}Copy as text</button></div>
    `)}`;
  };
  T.history.rail = 'history';

  /* ---------- 14 Settings ---------- */
  const preview = (k) => {
    const dark = k === 'dark';
    const half = k === 'system';
    const box = (bg, fg, sc) => `<span style="flex:1;background:${bg};display:flex;flex-direction:column;gap:6px;padding:12px"><span style="width:44px;height:44px">${P.shape('cookie12', 44, '#FFAFD0')}</span><span style="height:8px;width:70%;border-radius:4px;background:${fg}"></span><span style="height:8px;width:45%;border-radius:4px;background:${sc}"></span></span>`;
    return `<span style="display:flex;height:120px;border-radius:20px;overflow:hidden;border:1px solid var(--outline-var)">${half ? box('#FFF7FA', '#21181E', '#D6C2CA') + box('#19121D', '#F3E5F4', '#5E4F63') : dark ? box('#19121D', '#F3E5F4', '#5E4F63') : box('#FFF7FA', '#21181E', '#D6C2CA')}</span>`;
  };
  T.settings = () => `${P.rail('settings')}
    <aside class="pane" style="width:300px;flex:none;margin:12px 0;padding:20px 12px;display:flex;flex-direction:column;gap:3px">
      <span class="t-h2" style="padding:0 12px 12px">Settings</span>
      ${[['palette', 'Appearance'], ['pulse', 'Ping defaults'], ['monitor', 'Monitor'], ['bell', 'Notifications'], ['data', 'Data & export'], ['shield', 'Privacy'], ['info', 'About']].map(([icn, l], i) => `
        <button class="row a-rise-x" style="${d(i * 0.04)};gap:14px;height:56px;padding:0 16px;border-radius:${i === 0 ? 28 : 16}px;${i === 0 ? 'background:var(--secondary-c);color:var(--on-secondary-c);font-weight:700' : 'color:var(--on-surface)'}">${ic(icn, 22)}<span style="font-size:16px">${l}</span></button>`).join('')}
    </aside>
    ${main(`
      <h1 class="t-hl" style="margin:0">Appearance</h1>
      <h2 class="t-title" style="margin:20px 0 10px">Theme</h2>
      <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:16px">
        ${[['light', 'Light'], ['dark', 'Dark'], ['system', 'System']].map(([k, l], i) => `
          <button class="a-rise" style="${d(i * 0.05)};display:flex;flex-direction:column;gap:10px;padding:10px;border-radius:28px;${k === 'system' ? 'background:var(--secondary-c);color:var(--on-secondary-c)' : 'background:var(--surface-c)'}">${preview(k)}<span class="row" style="gap:8px;padding:0 6px 4px;font-weight:700;font-size:15px">${k === 'system' ? ic('check', 18, 2.8) : ''}${l}</span></button>`).join('')}
      </div>
      <div class="seg" style="margin-top:16px">
        <div class="item a-rise" style="${d(0.15)};min-height:72px"><span class="lead" style="color:var(--on-surface-var)">${ic('auto', 24)}</span><span class="txt"><span class="h">Dynamic color</span><span class="s">Use colors from your wallpaper (Android 12+). Turns off the accent below.</span></span><span class="switch"></span></div>
        <div class="item a-rise" style="${d(0.2)};min-height:96px"><span class="lead" style="color:var(--on-surface-var)">${ic('palette', 24)}</span><span class="txt"><span class="h">Accent</span><span class="s">Used for hero shapes, live values and primary actions</span></span>${P.accentChoice()}</div>
        <div class="item a-rise" style="${d(0.25)};min-height:72px"><span class="lead" style="color:var(--on-surface-var)">${ic('motion', 24)}</span><span class="txt"><span class="h">Expressive motion</span><span class="s">Spring physics, shape morphs and live-ticking numbers. Off follows the system's reduce-motion setting.</span></span><span class="switch on"></span></div>
      </div>
      <div class="row" style="margin-top:auto;gap:12px;padding:16px 20px;border-radius:24px;background:var(--surface-c)">
        ${P.logoMark(40, { tile: true })}<span class="col grow"><span class="t-title">Pulse 2.0.0</span><span class="t-sup">Apache-2.0 · made with Flutter</span></span><button class="btn text">Check for updates</button>
      </div>
    `)}`;
  T.settings.rail = 'settings';

  /* Rail wrapper for screens that don't add it themselves */
  ['ping', 'network', 'tools', 'pingDetail'].forEach((k) => {
    const fn = T[k], railKey = fn.rail;
    T[k] = () => `${P.rail(railKey)}${fn()}`;
  });
})();
