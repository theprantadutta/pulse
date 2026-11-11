/* ==========================================================================
   Pulse — phone screens (390 × 844 logical px). Each returns the inner HTML
   of a `.app.phone` element. Navigation: bottom navigation bar (4 tabs).
   ========================================================================== */
(function () {
  const P = window.Pulse, D = window.PulseData, ic = P.icon;
  const S = (P.phone = {});
  const d = (s) => `animation-delay:${s}s`;

  /* ---------- 01 Splash ---------- */
  S.splash = () => `
    <div class="safe-top"></div>
    <div class="col" style="flex:1;align-items:center;justify-content:center;gap:28px">
      <div class="a-pop">${P.logoMark(168, { animated: true })}</div>
      <div class="col a-rise" style="${d(0.35)};align-items:center;gap:8px">
        ${P.wordmark(52)}
        <span class="t-sup" style="font-size:15px">Network tools that feel alive</span>
      </div>
    </div>
    <div class="col a-fade" style="${d(0.6)};align-items:center;gap:10px;padding-bottom:64px">
      ${P.wavyLinear(160, 0.62)}
      <span class="t-label">Starting monitors…</span>
    </div>`;

  /* ---------- 02 Ping (home) ---------- */
  S.ping = () => {
    const sel = D.hosts[1];
    const others = [D.hosts[0], D.hosts[2], D.hosts[3]];
    const lead = [
      `<span style="width:40px;height:40px;border-radius:50%;background:var(--tertiary-c);color:var(--on-tertiary-c);display:grid;place-items:center">${ic('router', 20)}</span>`,
      `<span style="width:40px;height:40px;border-radius:20px 20px 8px 8px;background:var(--secondary-c);color:var(--on-secondary-c);display:grid;place-items:center">${ic('cloud', 20)}</span>`,
      `<span style="position:relative;width:40px;height:40px;display:grid;place-items:center;color:var(--on-primary-c)">${P.shape('cookie9', 40, 'var(--primary-c)', { style: 'position:absolute;inset:0' })}<span style="position:relative">${ic('code', 18)}</span></span>`,
    ];
    return `
    <div class="safe-top"></div>
    ${P.appbarLg('Ping', `<button class="icon-btn tonal" aria-label="Pause all">${ic('pause', 22, 2.4)}</button><button class="icon-btn" aria-label="Ping settings">${ic('tune', 22)}</button>`)}
    <div class="chips" style="padding:4px 20px 0" role="group" aria-label="Hosts">
      <button class="chip sel a-chip" aria-pressed="true">${ic('check', 18, 2.8)}Google DNS</button>
      <button class="chip a-chip" style="${d(0.05)}">Router</button>
      <button class="chip a-chip" style="${d(0.1)}">Cloudflare</button>
      <button class="chip a-chip" style="${d(0.15)}">GitHub</button>
    </div>
    <section aria-label="Google DNS latency" style="position:relative;height:222px;margin-top:8px;display:grid;place-items:center">
      <div class="a-morph" aria-hidden="true" style="position:absolute;left:104px;top:14px;width:206px;height:196px;background:var(--secondary-c)"></div>
      <div class="a-breathe" style="position:relative;width:220px;height:220px">
        ${P.shape('cookie12', 220, 'var(--pink)', { cls: 'a-spin', style: 'position:absolute;inset:0' })}
        <div class="col" style="position:absolute;inset:0;align-items:center;justify-content:center;color:var(--on-pink)">
          <span class="row" style="gap:6px;font-size:14px;font-weight:700"><span class="live a-blink"></span>${sel.host}</span>
          <span class="row" style="align-items:baseline;gap:2px"><span class="t-hero" data-tick="dns">${sel.ms}</span><span style="font-size:22px;font-weight:800">ms</span></span>
        </div>
      </div>
    </section>
    <div class="stats a-rise" style="${d(0.1)};grid-template-columns:repeat(4,1fr);margin:12px 16px 0">
      <div class="stat"><span class="k">Avg</span><span class="n">${sel.avg}</span></div>
      <div class="stat"><span class="k">Max</span><span class="n">${sel.max}</span></div>
      <div class="stat"><span class="k">Loss</span><span class="n" style="color:var(--tertiary)">0%</span></div>
      <div class="stat"><span class="k">Jitter</span><span class="n">${sel.jit}</span></div>
    </div>
    <section style="margin:14px 16px 0">
      <h2 class="t-label" style="margin:0 0 8px 4px;font-size:14px">Other hosts</h2>
      <div class="seg">${others.map((h, i) => `
        <button class="item a-rise" style="${d(0.2 + i * 0.06)};height:58px;min-height:58px">
          <span class="lead">${lead[i]}</span>
          <span class="txt"><span class="h">${h.name}</span><span class="s"${h.loss ? ' style="color:var(--lat-slow)"' : ''}>${h.loss ? `${h.loss}% loss · ` : ''}${h.host}</span></span>
          <span class="v" data-tick="${['router', 'cf', 'gh'][i]}">${P.fmt(h.ms)}<small>ms</small></span>
        </button>`).join('')}
      </div>
    </section>
    <button class="fab float">${ic('stop', 18)}Stop all</button>
    ${P.navbar('ping')}`;
  };

  /* ---------- 03 Ping detail (single host) ---------- */
  S.pingDetail = () => {
    const s = D.single;
    return `
    <div class="safe-top"></div>
    ${P.appbar(s.name, s.host, `<button class="icon-btn" aria-label="Ping settings">${ic('tune', 22)}</button><button class="icon-btn" aria-label="More">${ic('more', 22)}</button>`)}
    <section class="row" style="gap:16px;padding:4px 20px 0;align-items:center">
      <div class="a-breathe" style="position:relative;width:176px;height:176px;flex:none">
        ${P.shape('cookie12', 176, 'var(--pink)', { cls: 'a-spin', style: 'position:absolute;inset:0' })}
        <div class="col" style="position:absolute;inset:0;align-items:center;justify-content:center;color:var(--on-pink)">
          <span class="row" style="gap:6px;font-size:13px;font-weight:700"><span class="live a-blink"></span>Live</span>
          <span class="row" style="align-items:baseline;gap:2px"><span style="font-size:84px;font-weight:900;line-height:.95;letter-spacing:-.04em;font-variation-settings:'wdth' 120" data-tick="single">${s.ms}</span><span style="font-size:18px;font-weight:800">ms</span></span>
        </div>
      </div>
      <div class="col grow" style="gap:8px">
        <span class="pill lime a-chip" style="${d(0.2)};align-self:flex-start">${ic('check', 14, 3)}No loss</span>
        <span class="t-sup">Every 1 s · 56 bytes<br>Timeout 2 s</span>
        <span class="t-sup">Started 16:24 · 312 sent</span>
      </div>
    </section>
    <section class="card a-rise" style="${d(0.1)};margin:16px 16px 0;padding:14px 16px 12px">
      <div class="row" style="justify-content:space-between"><span class="t-title">Last 30 pings</span><span class="t-label">avg 39 ms</span></div>
      <div style="position:relative;margin-top:10px">
        <div aria-hidden="true" style="position:absolute;left:0;right:0;bottom:${Math.round((39 / 100) * 64)}px;border-top:2px dashed var(--outline-var)"></div>
        ${P.bars(s.spark, { h: 64, max: 100, w: 7, gap: 4 })}
      </div>
      <div class="row" style="justify-content:space-between;margin-top:6px"><span class="t-label">30 s ago</span><span class="t-label">now</span></div>
    </section>
    <div class="a-rise" style="${d(0.15)};display:grid;grid-template-columns:repeat(4,1fr);gap:6px;margin:12px 16px 0">
      ${[['Avg', s.avg, ''], ['Loss', '0%', 'color:var(--tertiary)'], ['Max', s.max, 'color:var(--lat-slow)'], ['Jitter', s.jit, '']].map(([k, v, st], i) => `
        <div class="stat" style="border-radius:${i === 0 ? '20px 6px 6px 20px' : i === 3 ? '6px 20px 20px 6px' : '6px'}"><span class="k">${k}</span><span class="n" style="${st}">${v}</span></div>`).join('')}
    </div>
    <div class="chips" style="padding:14px 16px 0">
      <button class="chip sm">${ic('timer', 16)}1 s</button><button class="chip sm">56 B</button><button class="chip sm">Timeout 2 s</button><button class="chip sm">${ic('bell', 16)}Alert</button>
    </div>
    <div style="padding:16px 16px 0;display:flex;gap:8px">
      <button class="btn lg pink" style="flex:1">${ic('stop', 18)}Stop</button>
      <button class="btn lg tonal" aria-label="Share">${ic('share', 20)}</button>
    </div>
    ${P.navbar('ping')}`;
  };

  /* ---------- 04 Network ---------- */
  S.network = () => {
    const n = D.net;
    const rows = [
      ['Local IPv4', n.ipv4, true], ['Subnet', n.subnet, true], ['Gateway', n.gateway, true],
      ['DNS 1', n.dns1, true], ['DNS 2', '—', false], ['MAC address', 'Hidden by Android', false], ['IPv6', 'Not assigned', false],
    ];
    return `
    <div class="safe-top"></div>
    ${P.appbarLg('Network', `<button class="icon-btn tonal" aria-label="Refresh">${ic('refresh', 22, 2.4)}</button>`)}
    <section class="a-rise" style="position:relative;margin:4px 16px 0;height:172px;border-radius:32px;background:var(--pink);color:var(--on-pink);overflow:hidden;padding:18px 20px">
      ${P.shape('cookie12', 190, 'rgba(255,255,255,.28)', { cls: 'a-spin', style: 'position:absolute;right:-46px;top:-40px' })}
      <div class="row" style="position:relative;gap:8px;font-size:13px;font-weight:700">${ic('wifi', 18, 2.6)}Connected · ${n.kind}</div>
      <div style="position:relative;font-size:52px;font-weight:900;letter-spacing:-.03em;line-height:1;margin-top:10px;font-variation-settings:'wdth' 125">${n.ssid}</div>
      <div class="row" style="position:relative;gap:8px;margin-top:16px">
        <span class="pill" style="background:var(--on-pink);color:var(--pink)">${ic('signal', 16, 2.6)}${n.signal} dBm · Good</span>
        <span class="pill" style="background:rgba(59,7,32,.12);color:var(--on-pink)">Link ${n.link} Mb/s</span>
      </div>
    </section>
    <div class="seg" style="margin:12px 16px 0">${rows.map(([k, v, copy], i) => `
      <div class="item a-rise" style="${d(0.08 + i * 0.04)};min-height:50px;padding:4px 8px 4px 16px">
        <span class="txt"><span class="s" style="font-size:12px">${k}</span><span class="h" style="font-size:16px;${copy ? '' : 'color:var(--on-surface-var);font-weight:500'}">${v}</span></span>
        ${copy ? `<button class="icon-btn" aria-label="Copy ${k}" style="width:40px;height:40px">${ic('copy', 20)}</button>` : k.startsWith('MAC') ? `<button class="icon-btn" aria-label="Why" style="width:40px;height:40px">${ic('info', 20)}</button>` : ''}
      </div>`).join('')}
    </div>
    <button class="fab float">${ic('lan', 20)}Scan network</button>
    ${P.navbar('net')}`;
  };

  /* ---------- 05 Tools hub ---------- */
  S.tools = () => `
    <div class="safe-top"></div>
    ${P.appbarLg('Tools', `<button class="icon-btn" aria-label="Settings">${ic('settings', 22)}</button>`)}
    <section style="display:grid;grid-template-columns:repeat(2,1fr);gap:10px;margin:4px 16px 0">
      ${P.TOOLS.map((t, i) => {
        const hot = t.k === 'monitor';
        return `<button class="a-rise" style="${d(i * 0.04)};height:138px;border-radius:${hot ? 32 : 28}px;padding:14px 16px;display:flex;flex-direction:column;justify-content:space-between;background:${hot ? 'var(--pink)' : 'var(--surface-c)'};color:${hot ? 'var(--on-pink)' : 'inherit'}">
          <span class="row" style="justify-content:space-between;width:100%">${hot ? `<span style="width:44px;height:44px;display:grid;place-items:center;position:relative;color:var(--pink)">${P.shape('diamond', 44, 'var(--on-pink)', { style: 'position:absolute;inset:0' })}<span style="position:relative">${ic(t.icon, 22, 2.3)}</span></span>` : P.toolBadge(t, 44)}
          ${hot ? `<span class="row" style="gap:6px;font-size:12px;font-weight:800"><span class="live a-blink"></span>LIVE</span>` : ''}</span>
          <span class="col"><span style="font-size:19px;font-weight:800;font-variation-settings:'wdth' 110">${t.name}</span><span class="ellip" style="font-size:13px;${hot ? '' : 'color:var(--on-surface-var)'}">${t.last}</span></span>
        </button>`;
      }).join('')}
    </section>
    ${P.navbar('tools')}`;

  /* ---------- 06 Traceroute ---------- */
  S.trace = () => {
    const xs = [...Array(21)].map((_, i) => 8 + i * 15.5);
    const ys = xs.map((_, i) => 28 + 9 * Math.sin(i * 0.62));
    let wave = ''; for (let k = 0; k <= 310; k += 3) { const x = 8 + k, i = k / 15.5; wave += (k ? 'L' : 'M') + x + ' ' + (28 + 9 * Math.sin(i * 0.62)).toFixed(1); }
    const col = (i) => (i <= 5 || i === 7) ? 'var(--lat-fast)' : i === 6 ? 'var(--lat-mid)' : 'var(--lat-slow)';
    const nodes = xs.map((x, i) => {
      if (i === 8 || i === 9) return `<circle class="a-node" style="animation-delay:${(0.1 + i * 0.04).toFixed(2)}s;fill:var(--surface-c);stroke:var(--outline)" stroke-width="2" stroke-dasharray="2 2" cx="${x}" cy="${ys[i].toFixed(1)}" r="4.5"/>`;
      if (i === 20) return `<path class="a-spin-f" style="fill:var(--pink);stroke:var(--surface-c)" stroke-width="2" d="${P.polar(x, ys[i], 11.5, 1.6, 9, 90)}"/>`;
      return `<circle class="a-node" style="animation-delay:${(0.1 + i * 0.04).toFixed(2)}s;fill:${col(i)}" cx="${x}" cy="${ys[i].toFixed(1)}" r="5"/>`;
    }).join('');
    const hl = [
      ['01', 'circle', 'var(--tertiary-c)', 'var(--on-tertiary-c)', 'Router', 'First hop is healthy', '4.4<small>ms</small>'],
      ['07', 'arch', 'var(--secondary-c)', 'var(--on-secondary-c)', '10.44.10.5', 'Small spike inside the ISP', '13<small>ms</small>'],
      ['9·10', 'dash', '', 'var(--on-surface-var)', 'No reply', '2 hops, probes timed out', '<span style="color:var(--outline)">—</span>'],
      ['11', 'diamond', 'var(--primary-c)', 'var(--on-primary-c)', 'Biggest jump', 'Hop 08 → 11', '<span class="pill pink" style="height:28px">+55 ms</span>'],
      ['21', 'cookie9', 'var(--pink)', 'var(--on-pink)', 'github.com', 'Reached in Singapore', '56<small>ms</small>'],
    ];
    return `
    <div class="safe-top"></div>
    ${P.appbar('Traceroute', '', `<button class="icon-btn pink" aria-label="Run again">${ic('refresh', 22, 2.4)}</button>`)}
    <label class="field" style="margin:4px 16px 0">${ic('search', 22)}<input value="github.com" aria-label="Target host"><span class="aux">20.205.243.166</span></label>
    <section class="row a-rise" style="justify-content:space-between;align-items:flex-end;margin:14px 20px 0">
      <span class="row" style="align-items:baseline;gap:6px"><span class="t-display">56</span><span class="col" style="font-size:15px;font-weight:700;line-height:1.2"><span>ms</span><span class="muted" style="font-weight:500">to reach</span></span></span>
      <span class="col" style="align-items:flex-end;gap:6px"><span class="pill lime">21 hops</span><span class="pill lav" style="border-radius:8px 15px 15px 8px">BD → SG</span></span>
    </section>
    <section class="card a-rise" style="${d(0.08)};margin:14px 16px 0;padding:14px 16px 8px">
      <div class="row" style="justify-content:space-between;font-size:13px;font-weight:600;color:var(--on-surface-var)"><span>Route</span><span>10 timeouts</span></div>
      <svg width="326" height="72" viewBox="0 0 326 72" style="margin-top:4px;overflow:visible" role="img" aria-label="Hops 1–8 fast, 9–10 no reply, jump at hop 11, github.com at hop 21">
        <path class="a-draw" style="--len:360;stroke-dasharray:360;stroke:var(--secondary-c)" d="${wave}" fill="none" stroke-width="3" stroke-linecap="round"/>
        ${nodes}
        <g class="a-bob"><rect x="145" y="0" width="36" height="16" rx="8" style="fill:var(--primary-c)"/><text x="163" y="11.5" text-anchor="middle" font-size="10" font-weight="800" style="fill:var(--on-primary-c)" font-family="Roboto Flex">+55</text></g>
        <g font-family="Roboto Flex" font-size="11" font-weight="600" style="fill:var(--on-surface-var)"><text x="2" y="62">You</text><text x="62" y="62" text-anchor="middle">Bangladesh</text><text x="324" y="62" text-anchor="end">Singapore</text></g>
      </svg>
    </section>
    <div class="row" style="justify-content:space-between;margin:12px 12px 4px 20px"><h2 class="t-title" style="margin:0;font-weight:700">Highlights</h2><button class="btn text sm">See all 21</button></div>
    <div class="seg" style="margin:0 16px">${hl.map(([n, sh, f, on, h, s, v], i) => `
      <button class="item a-rise" style="${d(0.2 + i * 0.05)};min-height:54px;padding:6px 16px 6px 10px">
        <span class="lead" style="color:${on}">${sh === 'dash' ? `<span style="width:38px;height:38px;border-radius:50%;border:2px dashed var(--outline);display:grid;place-items:center;font-size:11px;font-weight:800">${n}</span>` : `${P.shape(sh, 38, f, { style: 'position:absolute;inset:1px', cls: sh === 'cookie9' ? 'a-spin-f' : '' })}<span style="position:relative;font-size:13px;font-weight:800">${n}</span>`}</span>
        <span class="txt"><span class="h" style="font-size:15px">${h}</span><span class="s">${s}</span></span><span class="v" style="font-size:18px">${v}</span>
      </button>`).join('')}
    </div>
    ${P.navbar('tools')}`;
  };

  /* ---------- 07 Port scan ---------- */
  S.ports = () => {
    const openAt = [1, 5], filtAt = [38, 64];
    const cells = [...Array(66)].map((_, i) => {
      const st = openAt.includes(i) ? 'background:var(--pink)' : filtAt.includes(i) ? 'background:var(--lav)' : 'border:1.5px solid var(--outline-var)';
      return `<span class="a-cell" style="animation-delay:${(i * 0.008).toFixed(3)}s;width:11px;height:11px;border-radius:4px;box-sizing:border-box;${st}"></span>`;
    }).join('');
    return `
    <div class="safe-top"></div>
    ${P.appbar('Port scan', '', `<button class="icon-btn pink" aria-label="Scan again">${ic('play', 22)}</button>`)}
    <label class="field" style="margin:4px 16px 0">${ic('search', 22)}<input value="scanme.nmap.org" aria-label="Target host"><span class="aux">45.33.32.156</span></label>
    <div class="group sm" role="group" aria-label="Port range" style="margin:12px 16px 0">
      <button class="on">Common</button><button>1–1024</button><button>Custom</button>
    </div>
    <section style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:16px 24px 0">
      ${[['cookie9', 'var(--pink)', 'var(--on-pink)', 'Open', '2'], ['clover4', 'var(--lav)', 'var(--on-lav)', 'Filtered', '2'], ['pill', 'var(--lime)', 'var(--on-lime)', 'Time', '1.2s']].map(([sh, f, on, k, v], i) => `
        <div class="a-pop" style="${d(0.1 + i * 0.08)};position:relative;aspect-ratio:1;display:grid;place-items:center">
          ${P.shape(sh === 'pill' ? 'square' : sh, 96, f, { style: 'position:absolute;inset:0;width:100%;height:100%', cls: sh === 'cookie9' ? 'a-spin-f' : sh === 'clover4' ? 'a-wobble' : '' })}
          <span class="col" style="position:relative;align-items:center;color:${on}"><span style="font-size:12px;font-weight:700">${k}</span><span style="font-size:32px;font-weight:900;line-height:1;font-variation-settings:'wdth' 115">${v}</span></span>
        </div>`).join('')}
    </section>
    <section class="card a-rise" style="${d(0.2)};margin:16px 16px 0;padding:14px 16px">
      <div class="row" style="justify-content:space-between"><span class="t-title">Port map · common</span><span class="row" style="gap:10px;font-size:11px;font-weight:600;color:var(--on-surface-var)"><span class="row" style="gap:4px"><span style="width:9px;height:9px;border-radius:3px;background:var(--pink)"></span>Open</span><span class="row" style="gap:4px"><span style="width:9px;height:9px;border-radius:3px;background:var(--lav)"></span>Filtered</span></span></div>
      <div style="display:grid;grid-template-columns:repeat(22,11px);gap:3.5px;margin-top:12px">${cells}</div>
    </section>
    <div class="seg" style="margin:12px 16px 0">${D.ports.common.map((p, i) => `
      <div class="item a-rise" style="${d(0.25 + i * 0.05)};min-height:56px">
        <span style="width:62px;font-size:22px;font-weight:900;font-variation-settings:'wdth' 110">${p.port}</span>
        <span class="txt"><span class="h" style="font-size:15px">${p.svc}</span><span class="s">${p.banner}</span></span>
        <span class="pill ${p.state === 'open' ? 'pink' : 'out'}" style="height:28px">${p.state === 'open' ? 'Open' : 'Filtered'}</span>
      </div>`).join('')}
    </div>
    ${P.navbar('tools')}`;
  };

  /* ---------- 08 Speed test ---------- */
  S.speed = () => `
    <div class="safe-top"></div>
    ${P.appbar('Speed test', '', `<button class="btn outline sm" style="border-radius:10px;margin-right:4px">${ic('server', 16)}Cloudflare · DAC</button>`)}
    <div class="group" role="group" aria-label="Test phases" style="margin:8px 16px 0">
      <button class="done">${ic('check', 18, 2.8)}Ping 37</button>
      <button class="on" aria-current="step">${ic('down', 18, 2.8)}Download</button>
      <button>Upload</button>
    </div>
    <div style="display:flex;justify-content:center;margin-top:10px">
      ${P.wavyGauge(280, 0.36, `<span style="font-size:14px;font-weight:600;color:var(--on-surface-var)">Download</span>
        <span style="font-size:92px;font-weight:900;line-height:1;letter-spacing:-.04em;font-variation-settings:'wdth' 125" data-tick="dl">9.4</span>
        <span style="font-size:16px;font-weight:700;color:var(--primary)">Mbps</span>`)}
    </div>
    <section style="margin:8px 20px 0">
      <div class="row" style="justify-content:space-between;font-size:13px;color:var(--on-surface-var)"><span>Measuring download</span><span data-tick="secs">6.2 s</span></div>
      <div style="margin-top:6px">${P.wavyLinear(350, 0.62)}</div>
    </section>
    <section style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:18px 20px 0">
      ${[['clover4', 'var(--lime)', 'var(--on-lime)', 'Ping', '37', 'a-wobble'], ['sunny', 'var(--lav)', 'var(--on-lav)', 'Jitter', '27', 'a-spin']].map(([sh, f, on, k, v, cl], i) => `
        <div class="a-pop" style="${d(0.2 + i * 0.1)};position:relative;aspect-ratio:1;display:grid;place-items:center">
          ${P.shape(sh, 100, f, { cls: cl, style: 'position:absolute;inset:0;width:100%;height:100%' })}
          <span class="col" style="position:relative;align-items:center;color:${on}"><span style="font-size:12px;font-weight:700">${k}</span><span style="font-size:30px;font-weight:900;line-height:1;font-variation-settings:'wdth' 120">${v}</span><span style="font-size:11px;font-weight:700">ms</span></span>
        </div>`).join('')}
      <div class="a-pop" style="${d(0.4)};aspect-ratio:1;border-radius:50% 50% 18px 18px;border:2px dashed var(--outline-var);display:flex;flex-direction:column;align-items:center;justify-content:center;color:var(--on-surface-var)">
        <span style="font-size:12px;font-weight:700">Upload</span><span style="font-size:30px;font-weight:900;line-height:1">—</span><span style="font-size:11px;font-weight:700">next</span>
      </div>
    </section>
    <button class="btn lg tonal" style="position:absolute;left:16px;right:16px;bottom:100px">${ic('stop', 16)}Cancel test</button>
    ${P.navbar('tools')}`;

  /* ---------- 09 Packet loss ---------- */
  S.loss = () => {
    const lostAt = [5, 51];
    const cells = [...Array(300)].map((_, i) => {
      const st = i >= 89 ? 'background:var(--surface-highest)' : lostAt.includes(i) ? 'background:var(--lat-slow)' : 'background:var(--lat-fast)';
      return `<span${i < 89 ? ` class="a-cell" style="animation-delay:${(i * 0.006).toFixed(3)}s;` : ' style="'}width:8.6px;height:8.6px;border-radius:3px;${st}"></span>`;
    }).join('');
    return `
    <div class="safe-top"></div>
    ${P.appbar('Packet loss', '', `<button class="btn tonal sm" style="margin-right:4px">${ic('stop', 14)}Stop</button>`)}
    <label class="field" style="margin:4px 16px 0">${ic('search', 22)}<input value="1.1.1.1" aria-label="Target host"><span class="aux">5 min · 1/s</span></label>
    <section class="row" style="gap:16px;margin:14px 20px 0;align-items:center">
      <div class="a-pop" style="position:relative;width:170px;height:170px;flex:none;display:grid;place-items:center">
        ${P.shape('burst', 170, 'var(--pink)', { cls: 'a-spin', style: 'position:absolute;inset:0' })}
        <span class="col" style="position:relative;align-items:center;color:var(--on-pink)"><span style="font-size:13px;font-weight:700">Loss</span><span style="font-size:46px;font-weight:900;line-height:.95;letter-spacing:-.03em;font-variation-settings:'wdth' 110">2.2%</span></span>
      </div>
      <div class="col grow a-rise" style="${d(0.15)};gap:8px">
        <span class="pill lav" style="align-self:flex-start">Unstable</span>
        <span style="font-size:14px;line-height:1.4">Drops are isolated single packets, which points to mild congestion along the path.</span>
      </div>
    </section>
    <div class="stats a-rise" style="${d(0.2)};grid-template-columns:repeat(4,1fr);margin:16px 16px 0">
      <div class="stat"><span class="k">Sent</span><span class="n">89</span></div>
      <div class="stat"><span class="k">Lost</span><span class="n" style="color:var(--lat-slow)">2</span></div>
      <div class="stat"><span class="k">Late</span><span class="n">0</span></div>
      <div class="stat"><span class="k">Longest</span><span class="n">1</span></div>
    </div>
    <section style="margin:16px 20px 0">
      <div class="row" style="justify-content:space-between;font-size:13px;color:var(--on-surface-var)"><span>Elapsed 1:29 of 5:00</span><span>30%</span></div>
      <div style="margin-top:6px">${P.wavyLinear(350, 0.3)}</div>
    </section>
    <section class="card a-rise" style="${d(0.3)};margin:14px 16px 0;padding:14px 16px">
      <div class="row" style="justify-content:space-between"><span class="t-title">Timeline</span><span class="row" style="gap:10px;font-size:11px;font-weight:600;color:var(--on-surface-var)"><span class="row" style="gap:4px"><span style="width:9px;height:9px;border-radius:3px;background:var(--lat-fast)"></span>OK</span><span class="row" style="gap:4px"><span style="width:9px;height:9px;border-radius:3px;background:var(--lat-slow)"></span>Lost</span></span></div>
      <div style="display:grid;grid-template-columns:repeat(30,8.6px);gap:2.2px;margin-top:10px">${cells}</div>
    </section>
    ${P.navbar('tools')}`;
  };

  /* ---------- 10 LAN scan ---------- */
  S.lan = () => `
    <div class="safe-top"></div>
    ${P.appbar('LAN scan', '192.168.0.0/24 · 254 hosts', `<button class="icon-btn pink" aria-label="Scan again">${ic('refresh', 22, 2.4)}</button>`)}
    <section class="card a-rise" style="margin:4px 16px 0;padding:16px;display:flex;align-items:center;gap:16px">
      <div style="position:relative;width:84px;height:84px;display:grid;place-items:center;flex:none">${P.shape('clover4', 84, 'var(--lime)', { cls: 'a-wobble', style: 'position:absolute;inset:0' })}<span style="position:relative;font-size:40px;font-weight:900;color:var(--on-lime);font-variation-settings:'wdth' 120">3</span></div>
      <div class="col grow" style="gap:6px"><span class="t-title-lg">Devices found</span><span class="t-sup">Scan complete · 254 of 254 · 21.6 s</span>${P.wavyLinear(200, 1, { color: 'var(--tertiary)' })}</div>
    </section>
    <div class="chips" style="padding:12px 16px 0"><button class="chip sm sel">${ic('check', 16, 2.8)}All 3</button><button class="chip sm">Router</button><button class="chip sm">Phones</button><button class="chip sm">Unknown</button><button class="chip sm">ICMP + TCP</button></div>
    <section class="a-rise" style="${d(0.1)};margin:12px 16px 0;border-radius:28px;background:var(--secondary-c);color:var(--on-secondary-c);padding:14px 16px 16px">
      <div class="row" style="gap:14px">
        <span style="width:44px;height:44px;border-radius:50%;background:var(--lav);color:var(--on-lav);display:grid;place-items:center">${ic('router', 22)}</span>
        <span class="col grow"><span style="font-size:17px;font-weight:700">Router <span class="pill" style="height:22px;font-size:11px;padding:0 8px;background:var(--on-secondary-c);color:var(--secondary-c);vertical-align:2px">Gateway</span></span><span style="font-size:13px;opacity:.85">192.168.0.1</span></span>
        <span style="font-size:20px;font-weight:800">3.9<small style="font-size:12px;margin-left:2px">ms</small></span>
      </div>
      <div style="display:grid;grid-template-columns:repeat(2,1fr);gap:10px 16px;margin-top:14px;font-size:13px">
        <span class="col"><span style="opacity:.8;font-size:12px">Hostname</span><span style="font-weight:600">—</span></span>
        <span class="col"><span style="opacity:.8;font-size:12px">Vendor</span><span style="font-weight:600">—</span></span>
        <span class="col"><span style="opacity:.8;font-size:12px">MAC</span><span style="font-weight:600">Hidden by Android</span></span>
        <span class="col"><span style="opacity:.8;font-size:12px">First seen</span><span style="font-weight:600">Nov 8, 15:05</span></span>
      </div>
      <div class="row" style="gap:6px;margin-top:12px;flex-wrap:wrap"><span style="font-size:12px;opacity:.8;margin-right:2px">Open ports</span>${[53, 80, 443, 1900].map((p) => `<span class="pill" style="height:26px;background:var(--surface);color:var(--on-surface)">${p}</span>`).join('')}</div>
      <div class="row" style="gap:8px;margin-top:14px"><button class="btn sm pink">${ic('pulse', 16)}Ping</button><button class="btn sm" style="background:var(--surface);color:var(--on-surface)">${ic('port', 16)}Ports</button><button class="btn sm" style="color:var(--on-secondary-c);opacity:.5" disabled>${ic('power', 16)}Wake</button></div>
    </section>
    <div class="seg" style="margin:8px 16px 0">
      <button class="item a-rise" style="${d(0.2)}"><span class="lead"><span style="width:40px;height:40px;border-radius:12px;background:var(--tertiary-c);color:var(--on-tertiary-c);display:grid;place-items:center">${ic('phone', 20)}</span></span><span class="txt"><span class="h">This device</span><span class="s">192.168.0.251 · phone</span></span><span class="v">0.1<small>ms</small></span></button>
      <button class="item a-rise" style="${d(0.26)}"><span class="lead"><span style="width:40px;height:40px;border-radius:50%;border:2px dashed var(--outline);display:grid;place-items:center;color:var(--on-surface-var)">${ic('help', 20)}</span></span><span class="txt"><span class="h">Unknown device</span><span class="s">192.168.0.43</span></span><span class="v">30<small>ms</small></span></button>
    </div>
    ${P.navbar('tools')}`;

  /* ---------- 11 Geo IP ---------- */
  S.geo = () => `
    <div class="safe-top"></div>
    ${P.appbar('Geo IP', '', `<button class="btn text sm">My IP</button>`)}
    <label class="field" style="margin:4px 16px 0">${ic('search', 22)}<input value="github.com" aria-label="Lookup"><span class="aux">20.205.243.166</span></label>
    <div class="a-rise" style="margin:12px 16px 0">${P.geoMap(358, 250, [150, 30, 760, 580])}</div>
    <section class="row a-rise" style="${d(0.1)};justify-content:space-between;align-items:center;margin:14px 20px 0">
      <span class="col"><span class="t-hl" style="font-size:38px">Singapore</span><span class="t-sup">SG · Asia/Singapore · UTC+8</span></span>
      <span class="row" style="gap:6px"><button class="icon-btn tonal" aria-label="Ping this">${ic('pulse', 22)}</button><button class="icon-btn pink" aria-label="Trace route">${ic('route', 22)}</button></span>
    </section>
    <div class="row" style="gap:6px;margin:12px 20px 0"><span class="pill lime">2,887 km</span><span class="pill lav">55 ms</span><span class="pill soft">19 hops</span></div>
    <div class="seg" style="margin:12px 16px 0">${[['Org', 'Microsoft Azure Cloud (southeastasia)'], ['ASN', 'AS8075'], ['Coordinates', '1.2830 N, 103.8330 E'], ['Hosting', 'Yes · datacenter']].map(([k, v], i) => `
      <div class="item a-rise" style="${d(0.15 + i * 0.04)};min-height:46px;padding:4px 16px"><span class="s" style="width:96px;font-size:13px">${k}</span><span class="h" style="font-size:14px;flex:1;text-align:right">${v}</span></div>`).join('')}
    </div>
    ${P.navbar('tools')}`;

  /* ---------- 12 Monitor ---------- */
  S.monitor = () => `
    <div class="safe-top"></div>
    ${P.appbar('Monitor', '', `<button class="btn pink sm" style="margin-right:4px">${ic('plus', 16, 2.6)}Add</button>`)}
    <section class="row a-rise" style="gap:12px;margin:4px 16px 0;padding:10px 10px 10px 16px;border-radius:24px;background:var(--surface-c)">
      <span class="live a-blink" style="color:var(--tertiary)"></span><span class="grow" style="font-size:14px;font-weight:600">Running · 6 targets</span><button class="btn sm tonal">${ic('pause', 14, 2.6)}Pause</button>
    </section>
    <section class="row" style="gap:10px;margin:12px 16px 0;align-items:stretch">
      <div class="a-pop" style="position:relative;width:150px;height:150px;flex:none;display:grid;place-items:center">${P.shape('cookie12', 150, 'var(--lime)', { cls: 'a-spin', style: 'position:absolute;inset:0' })}<span class="col" style="position:relative;align-items:center;color:var(--on-lime)"><span style="font-size:12px;font-weight:700">Uptime 24h</span><span style="font-size:36px;font-weight:900;line-height:1;font-variation-settings:'wdth' 105">100%</span></span></div>
      <div class="col grow" style="gap:6px">
        <div class="stat" style="border-radius:20px 20px 6px 6px"><span class="k">Avg latency</span><span class="n">42 ms</span></div>
        <div class="stat" style="border-radius:6px"><span class="k">Incidents</span><span class="n" style="color:var(--tertiary)">0</span></div>
        <div class="stat" style="border-radius:6px 6px 20px 20px"><span class="k">Checks</span><span class="n">13</span></div>
      </div>
    </section>
    <div class="group sm" style="margin:12px 16px 0"><button class="on">24 h</button><button>7 d</button><button>30 d</button></div>
    <div class="seg" style="margin:12px 16px 0">${D.monitor.map((m, i) => `
      <button class="item a-rise" style="${d(0.15 + i * 0.05)};min-height:60px;gap:12px">
        <span class="txt" style="flex:none;width:118px"><span class="h" style="font-size:15px">${m.host}</span><span class="s">${m.name} · ${m.up}%</span></span>
        <span aria-hidden="true" style="flex:1;display:flex;gap:2px;height:22px;align-items:stretch">${[...Array(24)].map((_, j) => `<span style="flex:1;border-radius:3px;background:var(--lat-fast);opacity:${j === 23 ? 1 : 0.45}"></span>`).join('')}</span>
        <span class="v" style="width:42px;text-align:right">${m.ms}</span>
      </button>`).join('')}
    </div>
    ${P.navbar('tools')}`;

  /* ---------- 13 History ---------- */
  const H_TYPE = {
    geo: ['circle', 'var(--pink)', 'var(--on-pink)', 'pin'], loss: ['clover4', 'var(--lav)', 'var(--on-lav)', 'loss'],
    speed: ['sunny', 'var(--pink)', 'var(--on-pink)', 'gauge'], ports: ['square', 'var(--lime)', 'var(--on-lime)', 'port'],
    trace: ['arch', 'var(--lav)', 'var(--on-lav)', 'route'], lan: ['pill', 'var(--lime)', 'var(--on-lime)', 'lan'], ping: ['cookie9', 'var(--pink)', 'var(--on-pink)', 'pulse'],
  };
  P.historyItem = function (h, i, sel) {
    const [sh, f, on, icn] = H_TYPE[h.type];
    return `<button class="item a-rise${sel ? ' sel' : ''}" style="animation-delay:${(0.1 + i * 0.04).toFixed(2)}s;min-height:62px">
      <span class="lead" style="color:${on}">${P.shape(sh, 40, f, { style: 'position:absolute;inset:0' })}<span style="position:relative">${ic(icn, 20, 2.3)}</span></span>
      <span class="txt"><span class="h">${h.title}</span><span class="s">${h.t} · ${h.sub}</span></span><span class="v" style="font-size:18px">${h.val}</span></button>`;
  };
  S.history = () => {
    const today = D.history.filter((h) => h.day === 'Today');
    return `
    <div class="safe-top"></div>
    ${P.appbarLg('History', `<button class="icon-btn" aria-label="Search">${ic('search', 22)}</button><button class="icon-btn" aria-label="Export">${ic('export', 22)}</button>`)}
    <div class="chips" style="padding:4px 16px 0"><button class="chip sel a-chip">${ic('check', 18, 2.8)}All</button><button class="chip a-chip">Ping</button><button class="chip a-chip">Trace</button><button class="chip a-chip">Speed</button><button class="chip a-chip">Ports</button><button class="chip a-chip">LAN</button></div>
    <h2 class="t-label" style="margin:16px 0 8px 24px;font-size:14px">Today · ${today.length} runs</h2>
    <div class="seg" style="margin:0 16px">${today.slice(0, 9).map((h, i) => P.historyItem(h, i)).join('')}</div>
    ${P.navbar('history')}`;
  };

  /* ---------- 14 Settings ---------- */
  P.themeChoice = function (cur) {
    return `<div class="group" role="radiogroup" aria-label="Theme">${[['light', 'sun', 'Light'], ['dark', 'moon', 'Dark'], ['system', 'auto', 'System']].map(([k, icn, l]) =>
      `<button class="${k === cur ? 'on' : ''}" role="radio" aria-checked="${k === cur}">${ic(icn, 18)}${l}</button>`).join('')}</div>`;
  };
  P.accentChoice = function () {
    return `<div class="row" style="gap:12px">${[['cookie12', '#FFAFD0', true], ['clover4', '#DDBCFF'], ['sunny', '#CDEB74'], ['flower', '#A8C8FF']].map(([sh, c, on]) => `
      <button aria-label="Accent" style="position:relative;width:52px;height:52px;display:grid;place-items:center">${P.shape(sh, 52, c, { cls: on ? 'a-spin' : '' })}${on ? `<span style="position:absolute;color:#3B0720">${ic('check', 22, 3)}</span>` : ''}</button>`).join('')}</div>`;
  };
  S.settings = () => `
    <div class="safe-top"></div>
    ${P.appbar('Settings')}
    <div style="padding:0 16px;display:flex;flex-direction:column">
      <h2 class="t-label" style="margin:4px 0 8px 8px;font-size:14px;color:var(--primary)">Appearance</h2>
      <div class="seg">
        <div class="item a-rise" style="flex-direction:column;align-items:stretch;gap:10px;padding:14px 12px 12px"><span class="row" style="gap:12px;padding-left:4px">${ic('palette', 22)}<span class="t-title">Theme</span></span>${P.themeChoice('system')}</div>
        <div class="item a-rise" style="${d(0.05)}"><span class="lead" style="color:var(--on-surface-var)">${ic('auto', 22)}</span><span class="txt"><span class="h">Dynamic color</span><span class="s">Use wallpaper colors (Android 12+)</span></span><span class="switch"></span></div>
        <div class="item a-rise" style="${d(0.1)};flex-direction:column;align-items:stretch;gap:10px;padding:14px 16px"><span class="t-title">Accent</span>${P.accentChoice()}</div>
        <div class="item a-rise" style="${d(0.15)}"><span class="lead" style="color:var(--on-surface-var)">${ic('motion', 22)}</span><span class="txt"><span class="h">Expressive motion</span><span class="s">Springs and shape morphs</span></span><span class="switch on"></span></div>
      </div>
      <h2 class="t-label" style="margin:18px 0 8px 8px;font-size:14px;color:var(--primary)">Ping defaults</h2>
      <div class="seg">
        ${[['timer', 'Interval', '1 s'], ['data', 'Packet size', '56 bytes'], ['clock', 'Timeout', '2 s']].map(([icn, k, v], i) => `
          <button class="item a-rise" style="${d(0.2 + i * 0.04)};min-height:52px"><span class="lead" style="color:var(--on-surface-var)">${ic(icn, 22)}</span><span class="txt"><span class="h" style="font-weight:500">${k}</span></span><span style="font-size:15px;font-weight:700;color:var(--primary)">${v}</span></button>`).join('')}
      </div>
      <h2 class="t-label" style="margin:18px 0 8px 8px;font-size:14px;color:var(--primary)">Monitor &amp; alerts</h2>
      <div class="seg">
        <div class="item a-rise" style="${d(0.35)}"><span class="lead" style="color:var(--on-surface-var)">${ic('bell', 22)}</span><span class="txt"><span class="h">Notify on outage</span><span class="s">Loss over 5% or no reply for 1 min</span></span><span class="switch on"></span></div>
      </div>
    </div>
    ${P.navbar('tools')}`;
})();
