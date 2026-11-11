/* ==========================================================================
   Pulse prototype — shared building blocks: shapes, icons, logo, widgets.
   Every function returns an HTML string. Colors always come from CSS custom
   properties so the same markup renders in light and dark.
   ========================================================================== */
(function () {
  const P = (window.Pulse = window.Pulse || {});

  /* ---------- Shapes (Material 3 Expressive family) ----------
     Polar "cookie" shapes: r(θ) = R + A·cos(nθ). n = number of scallops.     */
  function polar(cx, cy, R, A, n, pts) {
    const f = (v) => (Math.round(v * 10) / 10).toString();
    let d = '';
    for (let i = 0; i < pts; i++) {
      const t = (2 * Math.PI * i) / pts;
      const r = R + A * Math.cos(n * t);
      const x = cx + r * Math.cos(t - Math.PI / 2);
      const y = cy + r * Math.sin(t - Math.PI / 2);
      d += (i ? 'L' : 'M') + f(x) + ' ' + f(y);
    }
    return d + 'Z';
  }
  P.polar = polar;

  // depth = scallop amplitude as a fraction of the outer radius
  const SHAPES = {
    cookie12: { n: 12, depth: 0.1 },
    cookie9:  { n: 9,  depth: 0.11 },
    cookie7:  { n: 7,  depth: 0.12 },
    cookie4:  { n: 4,  depth: 0.09 },
    clover4:  { n: 4,  depth: 0.2 },
    clover8:  { n: 8,  depth: 0.14 },
    sunny:    { n: 10, depth: 0.08 },
    burst:    { n: 12, depth: 0.16 },
    flower:   { n: 8,  depth: 0.22 },
  };
  P.shapePath = function (kind, size) {
    const s = SHAPES[kind];
    const outer = size / 2 - 0.5;
    const A = outer * s.depth;
    return polar(size / 2, size / 2, outer - A, A, s.n, s.n * 14);
  };

  /* shape(kind, size, fill, opts) — fill is a CSS color/var. opts.cls animates the path. */
  P.shape = function (kind, size, fill, opts = {}) {
    const cls = opts.cls ? ` class="${opts.cls}"` : '';
    const st = `style="fill:${fill}"`;
    let inner;
    if (SHAPES[kind]) inner = `<path${cls} ${st} d="${P.shapePath(kind, 100)}"/>`;
    else if (kind === 'circle') inner = `<circle${cls} ${st} cx="50" cy="50" r="49"/>`;
    else if (kind === 'square') inner = `<rect${cls} ${st} x="4" y="4" width="92" height="92" rx="30"/>`;
    else if (kind === 'arch') inner = `<path${cls} ${st} d="M4 50a46 46 0 0 1 92 0v30a16 16 0 0 1-16 16H20A16 16 0 0 1 4 80z"/>`;
    else if (kind === 'diamond') inner = `<rect${cls} ${st} x="17" y="17" width="66" height="66" rx="18" transform="rotate(45 50 50)"/>`;
    else if (kind === 'pill') inner = `<rect${cls} ${st} x="20" y="2" width="60" height="96" rx="30"/>`;
    else if (kind === 'slanted') inner = `<path${cls} ${st} d="M22 8h62a12 12 0 0 1 11.6 15l-15 62A12 12 0 0 1 69 94H16A12 12 0 0 1 4.4 79l15-62A12 12 0 0 1 22 8z"/>`;
    const style = opts.style ? ` style="${opts.style}"` : '';
    return `<svg width="${size}" height="${size}" viewBox="0 0 100 100" aria-hidden="true"${style}>${inner}</svg>`;
  };

  /* Wavy ring (used by the circular wavy progress indicator) */
  P.wavyRing = function (cx, cy, R, amp, waves) { return polar(cx, cy, R, amp, waves, waves * 10); };

  /* ---------- Icons (24px grid, 2px rounded strokes) ---------- */
  const I = {
    pulse:   '<path d="M3 12h4l3-8 4 16 3-8h4"/>',
    wifi:    '<path d="M2 9a15 15 0 0 1 20 0"/><path d="M5 12.5a10 10 0 0 1 14 0"/><path d="M8.5 16a5 5 0 0 1 7 0"/><circle cx="12" cy="19.5" r="1"/>',
    grid:    '<rect x="4" y="4" width="6.5" height="6.5" rx="3.25"/><rect x="13.5" y="4" width="6.5" height="6.5" rx="1.6"/><rect x="4" y="13.5" width="6.5" height="6.5" rx="1.6"/><rect x="13.5" y="13.5" width="6.5" height="6.5" rx="3.25"/>',
    clock:   '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
    tune:    '<path d="M4 7h10M18 7h2M4 17h4M12 17h8"/><circle cx="16" cy="7" r="2"/><circle cx="10" cy="17" r="2"/>',
    settings:'<circle cx="12" cy="12" r="3"/><path d="M12 2.8v2.4M12 18.8v2.4M4.2 7.5l2.1 1.2M17.7 15.3l2.1 1.2M4.2 16.5l2.1-1.2M17.7 8.7l2.1-1.2"/><circle cx="12" cy="12" r="7"/>',
    plus:    '<path d="M12 5v14M5 12h14"/>',
    pause:   '<path d="M9 6v12M15 6v12"/>',
    play:    '<path d="M8 5.5v13l10.5-6.5z" fill="currentColor" stroke="none"/>',
    stop:    '<rect x="6" y="6" width="12" height="12" rx="3" fill="currentColor" stroke="none"/>',
    back:    '<path d="M19 12H5M11 6l-6 6 6 6"/>',
    refresh: '<path d="M20 11a8 8 0 1 0-2.3 5.7"/><path d="M20 5v6h-6"/>',
    search:  '<circle cx="11" cy="11" r="6.5"/><path d="M16 16l4 4"/>',
    copy:    '<rect x="8" y="8" width="11" height="11" rx="2.5"/><path d="M16 8V6.5A2.5 2.5 0 0 0 13.5 4h-7A2.5 2.5 0 0 0 4 6.5v7A2.5 2.5 0 0 0 6.5 16H8"/>',
    share:   '<circle cx="18" cy="5.5" r="2.5"/><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="18.5" r="2.5"/><path d="M8.2 10.8l7.6-4M8.2 13.2l7.6 4"/>',
    trash:   '<path d="M5 7h14M10 4h4M7 7l1 12.5a1.5 1.5 0 0 0 1.5 1.5h5a1.5 1.5 0 0 0 1.5-1.5L17 7"/>',
    globe:   '<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.5 2.6 3.5 5.5 3.5 8.5s-1 5.9-3.5 8.5c-2.5-2.6-3.5-5.5-3.5-8.5s1-5.9 3.5-8.5z"/>',
    server:  '<rect x="4" y="4" width="16" height="7" rx="2.5"/><rect x="4" y="13" width="16" height="7" rx="2.5"/><path d="M8 7.5h.01M8 16.5h.01"/>',
    route:   '<circle cx="6" cy="18" r="2.5"/><circle cx="18" cy="6" r="2.5"/><path d="M8.5 18H15a3.5 3.5 0 0 0 0-7H9a3.5 3.5 0 0 1 0-7h6.5"/>',
    port:    '<rect x="4" y="6" width="16" height="12" rx="3"/><path d="M8 10v4M12 10v4M16 10v4"/>',
    gauge:   '<path d="M4.5 17a8.5 8.5 0 1 1 15 0"/><path d="M12 13l4-5"/><circle cx="12" cy="13" r="1.4" fill="currentColor"/>',
    loss:    '<circle cx="6" cy="12" r="2"/><circle cx="12" cy="12" r="2"/><path d="M16 10l4 4M20 10l-4 4"/>',
    lan:     '<rect x="9" y="3.5" width="6" height="5" rx="1.5"/><rect x="3" y="15.5" width="6" height="5" rx="1.5"/><rect x="15" y="15.5" width="6" height="5" rx="1.5"/><path d="M12 8.5v3.5M6 15.5V12h12v3.5"/>',
    pin:     '<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0C18.5 15.4 12 21 12 21z"/><circle cx="12" cy="10" r="2.3"/>',
    monitor: '<path d="M12 20s-7.5-4.6-7.5-10.2A4.3 4.3 0 0 1 12 7.2a4.3 4.3 0 0 1 7.5 2.6C19.5 15.4 12 20 12 20z"/><path d="M7 12h2.5l1.2-2 2 4 1.3-2H17"/>',
    bell:    '<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 0 0 4 0"/>',
    down:    '<path d="M12 5v14M6 13l6 6 6-6"/>',
    up:      '<path d="M12 19V5M6 11l6-6 6 6"/>',
    check:   '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    x:       '<path d="M7 7l10 10M17 7L7 17"/>',
    chevD:   '<path d="M6 9l6 6 6-6"/>',
    chevR:   '<path d="M9 6l6 6-6 6"/>',
    more:    '<circle cx="12" cy="5.5" r="1.2" fill="currentColor"/><circle cx="12" cy="12" r="1.2" fill="currentColor"/><circle cx="12" cy="18.5" r="1.2" fill="currentColor"/>',
    phone:   '<rect x="7" y="3" width="10" height="18" rx="2.5"/><path d="M11 17.5h2"/>',
    router:  '<rect x="3.5" y="13" width="17" height="6.5" rx="2.5"/><path d="M7 16.2h.01M10 16.2h.01M17 13V8M14.5 6.5a3.5 3.5 0 0 1 5 0"/>',
    laptop:  '<rect x="5" y="5" width="14" height="10" rx="1.5"/><path d="M3 18.5h18"/>',
    help:    '<circle cx="12" cy="12" r="8.5"/><path d="M9.6 9.5a2.5 2.5 0 0 1 4.8.8c0 1.7-2.4 2-2.4 3.7M12 16.8h.01"/>',
    filter:  '<path d="M4 6h16M7 12h10M10 18h4"/>',
    moon:    '<path d="M19.5 14.5A7.5 7.5 0 0 1 9.5 4.5a7.5 7.5 0 1 0 10 10z"/>',
    sun:     '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/>',
    auto:    '<circle cx="12" cy="12" r="8.5"/><path d="M12 3.5v17A8.5 8.5 0 0 0 12 3.5z" fill="currentColor"/>',
    palette: '<path d="M12 3.5a8.5 8.5 0 1 0 0 17c1.3 0 1.9-.9 1.9-1.8 0-1.4-1.2-1.6-1.2-2.8 0-1 .8-1.6 1.8-1.6h2.2a3.8 3.8 0 0 0 3.8-3.8C20.5 6.6 16.7 3.5 12 3.5z"/><circle cx="7.5" cy="11" r="1.1" fill="currentColor"/><circle cx="10" cy="7.3" r="1.1" fill="currentColor"/><circle cx="14.5" cy="7.3" r="1.1" fill="currentColor"/>',
    shield:  '<path d="M12 3.5l7 2.8v5.2c0 4.6-3 8-7 9-4-1-7-4.4-7-9V6.3z"/><path d="M9 12l2.2 2.2L15.5 10"/>',
    info:    '<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5.5M12 7.8h.01"/>',
    export:  '<path d="M12 15V4M7.5 8.5L12 4l4.5 4.5M5 13.5V18a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-4.5"/>',
    power:   '<path d="M12 4v7M7.2 6.8a7 7 0 1 0 9.6 0"/>',
    motion:  '<path d="M4 15c3 0 3-6 6-6s3 6 6 6 3-6 4-6"/>',
    data:    '<ellipse cx="12" cy="6" rx="7" ry="2.8"/><path d="M5 6v6c0 1.5 3.1 2.8 7 2.8s7-1.3 7-2.8V6M5 12v6c0 1.5 3.1 2.8 7 2.8s7-1.3 7-2.8v-6"/>',
    cloud:   '<path d="M7 18h10a4 4 0 0 0 .6-8A6 6 0 0 0 6 11a3.5 3.5 0 0 0 1 7z"/>',
    code:    '<path d="M8 9l-4 3 4 3M16 9l4 3-4 3M13.5 6l-3 12"/>',
    signal:  '<path d="M5 19v-3M9.5 19v-6M14 19v-9M18.5 19V6"/>',
    timer:   '<circle cx="12" cy="13" r="7.5"/><path d="M12 9.5V13l2.2 1.4M10 3h4"/>',
  };
  P.icon = function (name, size = 24, sw = 2.2, extraStyle = '') {
    const body = I[name] || I.help;
    return `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"${extraStyle ? ` style="${extraStyle}"` : ''}>${body}</svg>`;
  };
  P.ICONS = I;

  /* ---------- Logo A — "Heartbeat Cookie" ---------- */
  P.ECG = 'M26 62H43L50 46L60 80L69 38L76 62H94';
  P.logoMark = function (size, o = {}) {
    // o.tile: draw berry squircle; o.animated: spin + ecg draw + pump; o.mono: single color (CSS color); o.simple: small-size variant
    const cookieFill = o.mono || 'var(--pink)';
    const lineColor = o.mono ? (o.monoCut || 'var(--surface)') : 'var(--ecg)';
    const cookie = o.simple
      ? `<circle cx="60" cy="60" r="45" style="fill:${cookieFill}"/>`
      : `<path ${o.animated ? 'class="a-spin" ' : ''}style="fill:${cookieFill}" d="${polar(60, 60, 42, 4.5, 12, 168)}"/>`;
    const sw = o.simple ? 9 : 7;
    const line = `<path ${o.animated ? 'class="a-ecg" ' : ''}d="${P.ECG}" fill="none" style="stroke:${lineColor}" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round"/>`;
    const tile = o.tile ? `<rect width="120" height="120" rx="${o.round ? 60 : 36}" style="fill:var(--berry)"/>` : '';
    const scale = o.tile ? ' transform="translate(60 60) scale(.86) translate(-60 -60)"' : '';
    return `<svg width="${size}" height="${size}" viewBox="0 0 120 120" aria-hidden="true"${o.animated ? ' class="a-pump"' : ''}>${tile}<g${scale}>${cookie}${line}</g></svg>`;
  };
  P.wordmark = function (px, color = 'var(--on-surface)') {
    return `<span style="font-size:${px}px;font-weight:800;letter-spacing:-.02em;line-height:1;color:${color};font-variation-settings:'wdth' 125">Pulse</span>`;
  };

  /* ---------- Widgets ---------- */
  // latency → semantic color var
  P.latColor = function (ms) { return ms == null ? 'var(--outline)' : ms < 10 ? 'var(--lat-fast)' : ms <= 40 ? 'var(--lat-mid)' : 'var(--lat-slow)'; };
  P.fmt = function (v) { return v < 10 ? v.toFixed(1) : String(Math.round(v)); };

  // Pill bar sparkline. vals: numbers (null = lost packet)
  P.bars = function (vals, o = {}) {
    const h = o.h || 40, max = o.max || Math.max(...vals.filter((v) => v != null)) * 1.15, w = o.w || 6, gap = o.gap || 3;
    const out = vals.map((v, i) => {
      const delay = o.anim === false ? '' : `animation-delay:${(0.15 + i * 0.025).toFixed(3)}s;`;
      if (v == null) return `<span style="width:${w}px;height:${w}px;border-radius:${w}px;background:var(--lat-slow);flex:none;align-self:flex-start"></span>`;
      const bh = Math.max(w, Math.round((v / max) * h));
      const col = o.color || P.latColor(v);
      return `<span class="${o.anim === false ? '' : 'a-grow-y'}" style="${delay}width:${w}px;height:${bh}px;border-radius:${w}px;background:${col};flex:none;opacity:${o.op || 1}"></span>`;
    });
    return `<div aria-hidden="true" style="display:flex;align-items:flex-end;gap:${gap}px;height:${h}px">${out.join('')}</div>`;
  };

  // M3 Expressive wavy linear progress indicator (determinate)
  P.wavyLinear = function (width, frac, o = {}) {
    const end = Math.round(width * frac);
    const color = o.color || 'var(--primary)';
    let d = 'M-24 7q6 -5 12 0';
    const halves = Math.ceil((end + 48) / 12);
    for (let i = 0; i < halves; i++) d += 't12 0';
    const id = 'wl' + Math.random().toString(36).slice(2, 8);
    const track = frac < 1 ? `<line x1="${end + 10}" y1="7" x2="${width - 6}" y2="7" style="stroke:var(--secondary-c)" stroke-width="4" stroke-linecap="round"/><circle cx="${width - 2.5}" cy="7" r="2.5" style="fill:${color}"/>` : '';
    return `<svg width="${width}" height="14" viewBox="0 0 ${width} 14" aria-hidden="true"><defs><clipPath id="${id}"><rect x="0" y="0" width="${end}" height="14"/></clipPath></defs><g clip-path="url(#${id})"><path class="a-wave-x" d="${d}" fill="none" style="stroke:${color}" stroke-width="4" stroke-linecap="round"/></g>${track}</svg>`;
  };

  // M3 Expressive wavy circular gauge. frac = 0..1 of the full ring (starts at 12 o'clock)
  P.wavyGauge = function (size, frac, center, o = {}) {
    const R = 120, cx = 150, cy = 150;
    const ang = -90 + 360 * frac;
    const ex = cx + R * Math.cos((ang * Math.PI) / 180), ey = cy + R * Math.sin((ang * Math.PI) / 180);
    const large = frac > 0.5 ? 1 : 0;
    const len = ((2 * Math.PI * R * frac) + 2).toFixed(1);
    const id = 'wg' + Math.random().toString(36).slice(2, 8);
    const color = o.color || 'var(--pink)';
    return `<div style="position:relative;width:${size}px;height:${size}px;flex:none">
      <svg width="${size}" height="${size}" viewBox="0 0 300 300" style="position:absolute;inset:0" aria-hidden="true">
        <defs><mask id="${id}" maskUnits="userSpaceOnUse" x="0" y="0" width="300" height="300">
          <path class="a-draw" style="--len:${len};stroke-dasharray:${len} 2000" d="M150 30A120 120 0 ${large} 1 ${ex.toFixed(2)} ${ey.toFixed(2)}" fill="none" stroke="#fff" stroke-width="30" stroke-linecap="round"/>
        </mask></defs>
        <circle cx="150" cy="150" r="120" fill="none" style="stroke:var(--surface-high)" stroke-width="12"/>
        <g mask="url(#${id})"><path class="a-wave-rot" style="stroke:${color};transform-origin:150px 150px;animation:spin 17.6s linear infinite" fill="none" stroke-width="11" stroke-linejoin="round" d="${P.wavyRing(150, 150, 120, 4, 16)}"/></g>
      </svg>
      <div style="position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center">${center}</div>
    </div>`;
  };

  // Navigation (phone)
  const NAV = [['ping', 'pulse', 'Ping'], ['net', 'wifi', 'Network'], ['tools', 'grid', 'Tools'], ['history', 'clock', 'History']];
  P.navbar = function (active) {
    return `<nav class="navbar" aria-label="Primary">${NAV.map(([k, ic, l]) =>
      `<button class="nav-i${k === active ? ' on' : ''}"${k === active ? ' aria-current="page"' : ''}><span class="ind">${P.icon(ic, 22)}</span>${l}</button>`).join('')}</nav>`;
  };
  // Navigation rail (tablet)
  P.rail = function (active) {
    const items = NAV.map(([k, ic, l]) =>
      `<button class="rail-i${k === active ? ' on' : ''}"${k === active ? ' aria-current="page"' : ''}><span class="ind">${P.icon(ic, 22)}</span>${l}</button>`).join('');
    return `<nav class="rail" aria-label="Primary">
      <div class="brand">${P.logoMark(48, { tile: true })}</div>
      <button class="rail-fab" aria-label="New ping">${P.icon('plus', 24, 2.4)}</button>
      ${items}
      <div class="spacer"></div>
      <button class="rail-i${active === 'settings' ? ' on' : ''}"><span class="ind">${P.icon('settings', 22)}</span>Settings</button>
    </nav>`;
  };

  // Tools catalogue (shared by Tools hub, tablet tools pane)
  P.TOOLS = [
    { k: 'ping',    name: 'Ping',        icon: 'pulse',   shape: 'cookie9', fill: 'var(--pink)', on: 'var(--on-pink)', last: '63 ms · 7.8% loss' },
    { k: 'trace',   name: 'Traceroute',  icon: 'route',   shape: 'arch',    fill: 'var(--lav)',  on: 'var(--on-lav)',  last: '21 hops · BD → SG' },
    { k: 'ports',   name: 'Port scan',   icon: 'port',    shape: 'square',  fill: 'var(--lime)', on: 'var(--on-lime)', last: '2 open · 22, 80' },
    { k: 'speed',   name: 'Speed test',  icon: 'gauge',   shape: 'sunny',   fill: 'var(--pink)', on: 'var(--on-pink)', last: '9.4 ↓ · 7 ↑ Mbps' },
    { k: 'loss',    name: 'Packet loss', icon: 'loss',    shape: 'clover4', fill: 'var(--lav)',  on: 'var(--on-lav)',  last: '2.2% · unstable' },
    { k: 'lan',     name: 'LAN scan',    icon: 'lan',     shape: 'pill',    fill: 'var(--lime)', on: 'var(--on-lime)', last: '3 devices' },
    { k: 'geo',     name: 'Geo IP',      icon: 'pin',     shape: 'circle',  fill: 'var(--pink)', on: 'var(--on-pink)', last: 'Singapore' },
    { k: 'monitor', name: 'Monitor',     icon: 'monitor', shape: 'diamond', fill: 'var(--lav)',  on: 'var(--on-lav)',  last: '6 targets · live' },
  ];
  P.toolBadge = function (t, size = 40, iconSize) {
    return `<span style="position:relative;width:${size}px;height:${size}px;display:grid;place-items:center;flex:none;color:${t.on}">
      ${P.shape(t.shape, size, t.fill, { style: 'position:absolute;inset:0' })}
      <span style="position:relative">${P.icon(t.icon, iconSize || Math.round(size * 0.5), 2.3)}</span></span>`;
  };
  // Tablet: tools list pane
  P.toolsPane = function (active) {
    return `<aside class="pane" style="width:300px;flex:none;margin:12px 0 12px 0;padding:20px 12px;display:flex;flex-direction:column;gap:3px">
      <div class="row" style="justify-content:space-between;padding:0 8px 12px 12px"><span class="t-h2">Tools</span><button class="icon-btn" aria-label="Settings">${P.icon('settings', 22)}</button></div>
      ${P.TOOLS.map((t, i) => `<button class="row a-rise-x" style="animation-delay:${(i * 0.04).toFixed(2)}s;gap:12px;padding:8px 12px 8px 8px;border-radius:${t.k === active ? 28 : 16}px;${t.k === active ? 'background:var(--secondary-c);color:var(--on-secondary-c)' : ''}">
        ${P.toolBadge(t, 40)}<span class="col grow"><span class="t-title">${t.name}</span><span class="ellip" style="font-size:12px;${t.k === active ? 'opacity:.85' : 'color:var(--on-surface-var)'}">${t.last}</span></span></button>`).join('')}
    </aside>`;
  };

  /* Geo map: Natural Earth land in surface tones + route arc + markers.
     vb = visible window in map units [x, y, w, h]; container is w×h px (cover-fit). */
  P.geoMap = function (w, h, vb, o = {}) {
    const M = window.PULSE_MAP;
    const s = Math.max(w / vb[2], h / vb[3]);
    const ox = (w - vb[2] * s) / 2, oy = (h - vb[3] * s) / 2;
    const sc = (p) => [(p[0] - vb[0]) * s + ox, (p[1] - vb[1]) * s + oy];
    const a = M.dhaka, b = M.sg;
    const mx = (a[0] + b[0]) / 2, my = (a[1] + b[1]) / 2;
    const dx = b[0] - a[0], dy = b[1] - a[1], L = Math.hypot(dx, dy);
    const c = [mx + (dy / L) * 90, my - (dx / L) * 90];
    const A = sc(a), B = sc(b), C = sc(c);
    const route = `M${A[0].toFixed(1)} ${A[1].toFixed(1)} Q${C[0].toFixed(1)} ${C[1].toFixed(1)} ${B[0].toFixed(1)} ${B[1].toFixed(1)}`;
    const r = o.radius == null ? 28 : o.radius;
    return `<div role="img" aria-label="Map: route from Dhaka to Singapore" style="position:relative;width:${w}px;height:${h}px;border-radius:${r}px;overflow:hidden;background:var(--map-sea);flex:none">
      <svg width="${w}" height="${h}" viewBox="${vb.join(' ')}" preserveAspectRatio="xMidYMid slice" style="position:absolute;inset:0" aria-hidden="true">
        <path d="${M.landD}" style="fill:var(--map-land)"/>
        <path d="${M.borderD}" fill="none" style="stroke:var(--map-border)" stroke-width="1" vector-effect="non-scaling-stroke"/>
      </svg>
      <svg width="${w}" height="${h}" style="position:absolute;inset:0" aria-hidden="true">
        <path class="a-dash" d="${route}" fill="none" style="stroke:var(--primary)" stroke-width="2.5" stroke-dasharray="6 6" stroke-linecap="round"/>
      </svg>
      <span class="a-travel" aria-hidden="true" style="position:absolute;left:0;top:0;width:10px;height:10px;border-radius:50%;background:var(--primary);box-shadow:0 0 0 4px color-mix(in srgb, var(--primary) 25%, transparent);offset-path:path('${route}');opacity:0"></span>
      <span style="position:absolute;left:${(A[0] - 8).toFixed(1)}px;top:${(A[1] - 8).toFixed(1)}px;width:16px;height:16px;border-radius:50%;background:var(--lime);box-shadow:0 0 0 3px var(--on-lime)"></span>
      <span class="pill" style="position:absolute;left:${(A[0] + 14).toFixed(1)}px;top:${(A[1] - 15).toFixed(1)}px;height:26px;font-size:12px;background:var(--inverse-surface);color:var(--inverse-on-surface)">You · Dhaka</span>
      <span style="position:absolute;left:${(B[0] - 15).toFixed(1)}px;top:${(B[1] - 15).toFixed(1)}px;width:30px;height:30px">
        <span class="a-sonar" style="position:absolute;inset:4px;border-radius:50%;background:var(--pink);opacity:.6"></span>
        ${P.shape('cookie9', 30, 'var(--pink)', { cls: 'a-spin-f', style: 'position:absolute;inset:0' })}
      </span>
      <span class="pill" style="position:absolute;left:${(B[0] - 110).toFixed(1)}px;top:${(B[1] - 44).toFixed(1)}px;height:26px;font-size:12px;background:var(--pink);color:var(--on-pink)">Singapore</span>
    </div>`;
  };

  P.appbar = function (title, sub, actions = '') {
    return `<header class="appbar"><button class="icon-btn" aria-label="Back" style="color:var(--on-surface)">${P.icon('back', 24)}</button>
      <h1 class="title" style="margin:0">${title}${sub ? `<small>${sub}</small>` : ''}</h1>${actions}</header>`;
  };
  P.appbarLg = function (title, actions = '') {
    return `<header class="appbar-lg"><h1 class="t-hl" style="margin:0">${title}</h1><div class="row" style="gap:4px">${actions}</div></header>`;
  };
})();
