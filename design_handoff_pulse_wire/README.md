# Handoff: Pulse — "Wire" Redesign

## Overview
Full visual redesign of **Pulse** (github.com/theprantadutta/pulse), a Flutter network-diagnostics app for Windows, macOS, Linux, Android and iOS. The new direction, **Wire**, uses bold hard-edged grids, heavy condensed type, and the orange from the original Pulse logo. It covers 14 screens for desktop (≥1024px) and mobile (<600px), with light ("Paper") and dark ("Ink") themes.

## About the Design Files
The files in `screens/` are **design references created in HTML**. They are prototypes that show the intended look and layout, not production code to copy. The task is to **recreate them in the existing Flutter codebase** using its patterns (Riverpod, go_router, the `presentations/` folder layout). Open any `.dc.html` in a browser (keep `support.js` next to it). Each file is a pan/zoom canvas with a desktop frame (1280×800) and a mobile frame (390×844) for every screen.

All numbers, hosts and devices in the mocks are **sample data**.

## Fidelity
**High-fidelity.** Colors, type, borders and layout are final. Recreate them faithfully with Flutter widgets. Exact pixel sizes can adapt to real window sizes, but proportions, hierarchy and the border system must hold.

## Design Language (read first)
1. **Borders are the structure.** Every panel, cell, row, button and nav item sits on a **2px ink border** grid, with 1px hairlines between list rows. **Radius is always 0**; the rounded mobile bezel in the mocks is only a device frame.
2. **No blur shadows.** The only shadow is the hard offset on the desktop window/cards: `12px 12px 0 ink`. It is optional in-app and can be dropped for full-window desktop builds.
3. **Orange (Signal #E8612C) means "look here":** the live value, a latency spike, the primary action (START / SCAN / SAVE), an active incident, the logo block. Never decorative.
4. **Selected = inverse:** ink fill with paper text (nav item, segmented option, tab). Warning or selected row = Signal tint.
5. **Type:** headlines, numbers, nav and buttons use **Archivo**, heavy (800–900), condensed (wdth 62–80), UPPERCASE. Data, labels and body use **Space Mono**.
6. **Dark theme is a strict inversion.** Swap paper↔ink everywhere (backgrounds, borders, text, inverse fills). Keep Signal orange, and keep text on orange as #111111.

## Design Tokens
See `tokens/colors.json`, `tokens/tokens.css` and the ready-to-use **`tokens/wire_theme.dart`** (a `ThemeExtension` + `ThemeData` builder + text roles).

### Colors
| Token | Light (Paper) | Dark (Ink) | Use |
|---|---|---|---|
| background | #F2F0EB | #111111 | app background |
| ink | #111111 | #F2F0EB | text, all borders, inverse fill |
| signal | #E8612C | #E8612C | accent / live / CTA |
| onSignal | #111111 | #111111 | text on signal |
| signalTint | #F6C9B3 | #4A2616 | selected / warning row |
| surfaceInput | #FFFFFF | #1C1C1C | text fields |
| mutedRow | #E4E0D8 | #262523 | timeout / disabled / "this device" row |
| gridLine | #D9D5CC | #2E2D2A | chart gridlines |
| filtered | #8E8A82 | #6E6A63 | neutral state cells (filtered port) |
| text2 | #4A4740 | #B5B0A6 | secondary text |
| text3 | #6B675E | #8C877D | hints |
| degraded | #C98A2E | #E0A445 | late packet / degraded block |
| chartBar | #111111 | #F2F0EB | normal chart bars (spikes = signal) |

User-selectable accent (Settings): Orange #E8612C (default), Blue #3B6FE0, Green #1E9E62, Yellow #D6B400. The accent only replaces `signal`.

### Typography
| Role | Font | Weight | wdth | Size (desktop / mobile) |
|---|---|---|---|---|
| Hero numeral | Archivo | 900 | 62 | 190–210 / 150–190, line-height 0.85, unit suffix at ~28% size in signal |
| Display | Archivo | 900 | 62–70 | 54–120 / 48–76 |
| Stat value | Archivo | 900 | 70 | 30–40 / 22–32 |
| Screen / section title | Archivo | 900 | 72–75 | 26–32 |
| Nav / button | Archivo | 800 | 80 | 16–20, UPPERCASE |
| Data (IPs, hosts) | Space Mono | 700 | — | 13–20 |
| Body | Space Mono | 400 | — | 12–14, line-height 1.5 |
| Label | Space Mono | 700 | — | 10–12, UPPERCASE |

Fonts are OFL-licensed Google Fonts. **Bundle the variable Archivo TTF** (wdth 62–125, wght 100–900) plus Space Mono Regular/Bold under `assets/fonts/`, because the `google_fonts` package does not expose the width axis reliably. Remove the old Fira Code default.

### Spacing, borders, sizes
- Spacing steps: 2, 4, 8, 10, 12, 14, 16, 20, 24, 28, 32.
- Borders: 2px structural, 1px between list rows.
- Desktop: top bar 64px tall; sidebar 220px wide; right detail panel 320–420px; logo cell = sidebar width × 64, filled signal.
- Desktop nav item: 10px × 20px padding, Archivo 800/80% 17px uppercase, index number right-aligned in Space Mono 11px.
- Mobile: content sits in a 2px-bordered container inset 16px from the screen edges. Screen header bar 48px tall (ink fill, paper title; or signal fill on the Ping screen). Bottom tab bar: 4 equal cells (PING, NET, TOOLS, HISTORY) with 2px borders, 12px vertical padding, Space Mono 700 11px, active = inverse. Primary action bar 56px tall.
- Minimum hit target 44px on mobile.

## Information Architecture
**Desktop sidebar (12 items, numbered):** 01 Ping · 02 Traceroute · 03 Port scan · 04 Speed test · 05 Packet loss · 06 Network · 07 LAN scan · 08 Geo IP · 09 Monitor · 10 Alerts · 11 History · 12 Settings. The footer shows the connection (`● WIFI / HOME-5G`, local IP).

**Mobile tabs:** PING, NET (Network info → LAN scan), TOOLS (hub → every tool, Monitor, Alerts, Settings), HISTORY. Tool screens push with a `←` back button in the header.

**Responsive:** ≥1024px → sidebar + top bar layout. 600–1023px → collapse the sidebar to its index numbers only (or a NavigationRail) and stack right panels below the main area. <600px → mobile layout.

## Screens
File → screen numbers: `Wire 1 - Ping` (01–03), `Wire 2 - Network` (04–06), `Wire 3 - Diagnostics` (07–11), `Wire 4 - Monitor and Settings` (12–14), `Wire 0 - Palette` (tokens sheet), `Wire 5 - Brand` (logo/icons/splash). A PNG of every screen is in `screenshots/`, named `NN_screen_desktop.png` / `NN_screen_mobile.png`.

### 01 Ping / Live
- **Purpose:** continuously ping a target and read latency at a glance.
- **Desktop top bar:** `TARGET>` field (Space Mono 700 20px) + resolved hostname in text3, chips COUNT ∞ / INT 1.0s / T/O 5s (tap to open Configure), and a primary button (■ STOP while running, ink fill; ▶ START when idle, signal fill).
- **Hero row:** left cell "RTT / NOW" with the current latency in hero numerals and an "MS" suffix in signal. Right side: a stat strip with 5 cells (SENT, LOSS, MIN, AVG, MAX), and below it a bar chart of the last 30 replies (bars in chartBar, bars over 60 ms in signal, gridlines every 40px).
- **Bottom:** reply log table (SEQ, TIMESTAMP ms precision, RTT, TTL, STATE OK/SLOW/TIMEOUT; slow rows use signalTint, header row is inverse) and a RECENT TARGETS list (host + ms; tapping re-pings).
- **Mobile:** signal header "PING ● LIVE", target row with CONFIG link, hero number, last-20 bar chart, 2×2 stats (AVG, LOSS, MAX, JITTER), full-width STOP bar.

### 02 Ping / Configure
- Desktop: the target field becomes a white input with a signal caret. The main column shows a SUGGESTIONS dropdown (recent / preset / domain tag) and a QUICK TARGETS 3×2 grid (Google DNS, Cloudflare, Router, AWS Mumbai, GitHub, + Add). A right PARAMETERS panel has segmented controls for COUNT (4/10/50/∞), INTERVAL (0.2/0.5/1/2 s), TIMEOUT (1/2/5/10 s), PACKET SIZE (32/56/512/1472 B) and IP VERSION (AUTO/IPv4/IPv6/BOTH), plus a "Save as default" switch.
- Mobile: a bottom sheet over the dimmed Ping screen with the same controls and a signal "▶ START PING" bar.
- Segmented control: 2px border, equal cells split by 2px lines, active cell inverse.

### 03 History
- Desktop: the top bar has a filter field, a tool dropdown and EXPORT CSV. The session table has columns WHEN, TARGET, TOOL, AVG, LOSS and TREND (a 12-bar sparkline). The right panel shows the selected session: 6 stats in a 2-column grid, a full chart, and RE-RUN / .TXT / DELETE.
- Mobile: filter tabs ALL / PING / TRACE / SPEED, then session rows (host, meta line, avg value on the right).

### 04 Network Info
- Hero: `● CONNECTED · WI-FI`, SSID in display type (120px), and a chip strip (WI-FI 6, 5 GHZ, CH 44, WPA3, VPN ON/OFF inverse). Beside it: SIGNAL dBm with a 4-block meter (hollow block = missing strength) and LINK SPEED.
- Two tables, ADDRESSING (local IPv4, subnet, gateway, DNS 1/2, MAC, IPv6) and INTERNET (public IP, ISP, ASN, location, GW ping, DNS ping, IPv6 net). Every row has a bordered COPY button. The top bar has COPY ALL and ↻ REFRESH.
- Mobile: a signal hero block with the SSID, SIGNAL/LINK stats, and a detail list with COPY.

### 05 LAN Scan
- The top bar shows the subnet (CIDR) and host count, method (ARP + ICMP), and SCAN AGAIN. A summary row shows "N DEVICES FOUND" and a progress bar (2px border, fill = ink or signal).
- Device table: IP, DEVICE (+ tag GATEWAY / THIS DEVICE / NEW), VENDOR (from the MAC OUI), TYPE, RTT. "This device" = mutedRow; selected = signalTint.
- Right panel: device detail (hostname, MAC, vendor, open ports, first seen) and actions PING / PORTS / WAKE (Wake-on-LAN).
- Mobile: live-scanning state with a progress bar ("182 / 254", "probing .182").

### 06 Geo IP
- LOOKUP field (domain → resolved IP), MY IP shortcut, LOCATE.
- Map area: placeholder in the mock (striped). Implement with `flutter_map` + OSM tiles styled grayscale. Markers are square: YOU = 16px ink, TARGET = 22px signal with a 2px ink border. A bottom strip shows DISTANCE, RTT and HOPS.
- Right panel: a signal block with the city in display type and the country/timezone, then IP, CITY, ORG, ASN, COORDS, POSTAL, HOSTING. Actions: PING THIS, TRACE ROUTE.

### 07 Tools Hub (mobile only)
- A 2-column grid of 8 bordered tiles: index, tool name (Archivo 26px), last result in Space Mono. The Monitor tile uses signal fill. SETTINGS is in the header.

### 08 Traceroute
- Target, MAX 30 HOPS, 3 PROBES, RUN AGAIN.
- Hop table: HOP number (Archivo 30px), host + IP + the 3 probe times, an RTT bar (2px-bordered track, fill width ∝ RTT, final hop in signal), and a country code. Timeout rows (`* * *`) use mutedRow.
- Right panel: "DESTINATION REACHED · 7 HOPS" in signal, TOTAL RTT, TIMEOUTS, a ROUTE diagram (country boxes joined by a 2px line, with the added latency labelled), and a plain-language "BIGGEST JUMP" insight. COPY / SAVE.

### 09 Port Scan
- Presets COMMON / 1–1024 / CUSTOM (segmented), ▶ SCAN.
- Stats: SCANNED, OPEN (signal cell), FILTERED, TIME.
- Port map: a 32-column grid of square cells (each cell = 4 ports; open = signal, filtered = `filtered` color, closed = empty with a 1px border) and a legend.
- Open-ports table: PORT (Archivo), SERVICE + banner, STATE.

### 10 Speed Test
- A 4-step progress strip: 1 PING → 2 DOWNLOAD → 3 UPLOAD → 4 RESULT. Done = inverse with ✓, current = signal.
- Live value in hero numerals with an "MBPS" suffix, a 40-segment gauge (non-linear scale 0/50/100/250/500+), and a throughput-over-time bar chart (download bars ink, upload bars signal).
- Right panel: DOWNLOAD result, PING, JITTER, PAST RESULTS list. Server selector in the top bar.

### 11 Packet Loss Test
- Target, DURATION, RATE, STOP. Hero: loss % in hero numerals on a signal block.
- Stats: SENT, LOST, LATE (>150 ms), LONGEST BURST. A progress bar shows elapsed / total and a plain-language verdict (e.g. "bursts every ~40 s — Wi-Fi interference").
- Timeline: a grid with 1 cell per packet. OK = ink, late = degraded, lost = signal, pending = mutedRow.
- Actions: EXPORT CSV, SET ALERT ON LOSS, COMPARE TO 1.1.1.1.

### 12 Monitor
- Background monitoring of several targets. On desktop it runs from the system tray; on mobile it runs as a foreground service or WorkManager task.
- Stats: UPTIME 24H (signal), AVG LATENCY, INCIDENTS, CHECKS. Range picker 24H / 7D / 30D, + ADD TARGET.
- Target rows: host + name, a 48-block status strip (30 min per block: healthy ink, degraded, down signal), UPTIME, current ms. A row with an active incident = signalTint.
- Right panel: INCIDENTS list (time, duration or ONGOING, title, description).

### 13 Alerts
- Rules list: title, condition sentence, meta (channels, last fired), and a square toggle (2px border; on = ink track + signal knob).
- Rule editor (right panel on desktop, pushed screen on mobile): WATCH target, WHEN (LATENCY / LOSS / DOWN), IS ABOVE threshold (20-segment block slider + big value), FOR AT LEAST (10S/30S/1M/5M), NOTIFY VIA (PUSH / TRAY / SOUND toggle chips), DELETE / SAVE RULE.
- Mobile: an active-alert banner in signal at the top with DISMISS, then the rules and RECENTLY FIRED.

### 14 Settings
- Desktop: a 3-column layout (app sidebar | section list | content). Sections: APPEARANCE, PING DEFAULTS, MONITOR, NOTIFICATIONS, DATA & EXPORT, PRIVACY, ABOUT.
- Appearance: theme cards PAPER / INK / SYSTEM (mini previews; selected card has a hard signal offset shadow and a ✓), and ACCENT swatches (40px squares, selected = hard ink shadow).
- Data: keep history (90 days), export format (CSV/TXT), export folder, clear all data.
- The mobile mock is shown **in dark theme** as the reference for dark mode.

## Interactions & Behavior
- **START/STOP** toggles the ping stream. While running: the header shows ● LIVE, the hero value updates on every reply, the chart shifts left, and the log prepends. On stop, the session is saved to History.
- A reply over 60 ms (configurable) is marked SLOW: signal bar + signalTint row. A timeout shows `—` in the hero and a TIMEOUT row.
- Motion is minimal and mechanical: no easing bounces. Chart bars grow in over 120ms linear, value changes are instant (no count-up), and panels and sheets slide in over 180ms `Curves.easeOut`. Offer an optional 1px ink "scanline" progress for long-running tools.
- **Hover (desktop):** nav items, rows and buttons show a signalTint fill. **Pressed:** inverse. **Focus:** a 2px signal outline offset 2px.
- Every COPY writes to the clipboard and swaps the label to COPIED for 1.2s.
- Empty states: a big condensed headline plus one mono line and a primary action, e.g. "NO HISTORY YET / Run a ping and it lands here. / ▶ START PING".
- Errors (no network, DNS failure): replace the hero with "UNREACHABLE" in display type on a signalTint block, and put the reason in mono.

## State (Riverpod)
- `pingSessionProvider` — target, params (count, interval, timeout, size, ipVersion), running flag, replies list (seq, ts, rtt, ttl, status), derived stats (sent, lost, min, avg, max, jitter).
- `networkInfoProvider` — SSID, band, channel, security, RSSI, link speed, local/public IP, gateway, subnet, DNS, MAC, IPv6, ISP/ASN/location (ip-api / ipinfo), VPN flag; refresh action.
- `lanScanProvider`, `traceProvider`, `portScanProvider`, `speedTestProvider`, `lossTestProvider` — each with progress + results streams.
- `monitorProvider` (targets, 30-min buckets, incidents) and `alertRulesProvider` (rules + fired log) — persisted.
- `historyProvider` — persisted sessions (drift / sqflite / hive), with export to CSV/TXT via `path_provider` + `file_picker`.
- `settingsProvider` — theme mode, accent color, ping defaults, retention, export format. Persisted in SharedPreferences (replace the current flex_color_scheme selection).

## Brand & Assets
The brand sheet is `screens/Wire 5 - Brand.dc.html`.

### The mark
A six-point **lightning bolt** with straight edges only. It sits in front of a hard paper (#F2F0EB) offset copy placed 5% right and 5% down.
- Bolt polygon, 104×104 viewBox: `64,4 20,58 46,58 36,96 80,40 54,40`
- Offset polygon: `69,9 25,63 51,63 41,101 85,45 59,45`
- Inside a square, the bolt box is 62% of the square, centered.
- Colourways:
  - **Primary:** ink bolt on signal.
  - **Dark:** signal bolt on ink.
  - **Mono:** one colour, no offset.
- Drop the offset below 32px. Minimum size is 16px.
- Never rotate, outline, add a gradient or recolour outside these colourways.
- The bolt always comes before the word PULSE.

### Where to use what (use it everywhere)
| Place | Asset |
|---|---|
| Desktop sidebar logo cell (220×64, signal fill) | inline bolt 28×34 (`svg/pulse_mark.svg`, ink + paper offset) + "PULSE" Archivo 900 / wdth 75 / 32px, gap 10 |
| Mobile screen headers | text only (screen name); the brand appears on splash, Tools hub header and About |
| About / Settings footer | `logo/pulse_wordmark_light.png` / `_dark.png` (or the SVG mark + live text) |
| Empty states | mono mark 64px in text3 color above the headline |
| Notifications (Android small icon) | `icon/android/adaptive/ic_launcher_monochrome_*.png` → `res/drawable/ic_stat_pulse.png` (white on transparent) |
| System tray / menu bar (desktop) | `in_app/mark_light_24.png` / `mark_dark_24.png` (macOS: use mono template image) |
| Window title bar icon (Windows/Linux) | `icon/windows/app_icon_32.png` / `_48.png` |
| README / store listings / GitHub social | `logo/pulse_lockup_horizontal_light.png` (1920×480), `pulse_lockup_stacked.png` (960×1200) |
| Web favicon + PWA | `icon/web/*` → replace files in `web/` and `web/icons/`, update `manifest.json` theme_color `#E8612C`, background_color `#F2F0EB` |
| In-app image widget sizes | `in_app/mark_{light,dark}_{24,32,48,64,96,128}.png`, or better, render `svg/pulse_mark.svg` with `flutter_svg` |

### App icons (`assets/icon/`)
- `master/`:
  - `pulse_icon_light_1024.png` (primary)
  - `pulse_icon_dark_1024.png`
  - `pulse_mark_transparent_1024.png`
  - mono black and white versions
- `ios/`: AppIcon 20–1024 (no alpha) plus `AppIcon-dark-1024.png` for the iOS 18 dark appearance.
- `android/`:
  - legacy `mipmap-*/ic_launcher.png` (48–192)
  - `play_store_512.png`
  - `adaptive/`: foreground (transparent, bolt inside the 66dp safe zone), solid signal background, and monochrome (Android 13 themed icons)
- `macos/`: 16–1024 with the rounded-rect shape and ~10% transparent margin baked in, per Big Sur+ guidelines.
- `windows/`: 16–256 PNG. Build `windows/runner/resources/app_icon.ico` from them (flutter_launcher_icons does this).
- `web/`: favicon 16/32/48, apple-touch-icon 180, Icon-192/512, maskable 192/512.
- `svg/`: `pulse_icon_light.svg`, `pulse_icon_dark.svg`, `pulse_mark.svg`, `pulse_mark_dark.svg`, `pulse_mark_mono.svg` (uses currentColor).

Suggested `flutter_launcher_icons.yaml`:
```yaml
flutter_launcher_icons:
  image_path: "assets/brand/icon/master/pulse_icon_light_1024.png"
  android: "ic_launcher"
  adaptive_icon_background: "#E8612C"
  adaptive_icon_foreground: "assets/brand/icon/android/adaptive/ic_launcher_foreground_1024.png"
  adaptive_icon_monochrome: "assets/brand/icon/android/adaptive/ic_launcher_monochrome_1024.png"
  ios: true
  remove_alpha_ios: true
  image_path_ios_dark_transparent: "assets/brand/icon/master/pulse_mark_transparent_1024.png"
  web: { generate: true, background_color: "#F2F0EB", theme_color: "#E8612C" }
  windows: { generate: true, icon_size: 256 }
  macos: { generate: true, image_path: "assets/brand/icon/macos/app_icon_1024.png" }
```

### Splash screens (`assets/splash/`)
- **Mobile light:** signal #E8612C background, centered bolt (ink + paper offset), wordmark near the bottom. **Mobile dark:** ink #111111 background with a signal bolt. See `screenshots/splash_mobile_*.png`.
- `splash_center_{light,dark}_768.png` — the centered image for pre-Android-12 and iOS.
- `splash_android12_{light,dark}_1152.png` — the Android 12+ splash icon (bolt within the central 768px circle).
- `splash_desktop_window.png` — a 720×440 desktop launch window. Implement it as a Flutter route shown while providers initialise: logo panel + PULSE + a determinate progress bar with a status line ("Reading network interfaces…").

Suggested `flutter_native_splash.yaml`:
```yaml
flutter_native_splash:
  color: "#E8612C"
  image: assets/brand/splash/splash_center_light_768.png
  color_dark: "#111111"
  image_dark: assets/brand/splash/splash_center_dark_768.png
  android_12:
    color: "#E8612C"
    image: assets/brand/splash/splash_android12_light_1152.png
    color_dark: "#111111"
    image_dark: assets/brand/splash/splash_android12_dark_1152.png
  web: true
  fullscreen: false
```

### Logo files (`assets/logo/`)
- `pulse_lockup_horizontal_light.png` / `_dark.png` (1920×480)
- `pulse_lockup_stacked.png` (960×1200)
- `pulse_wordmark_light.png` / `_dark.png` (1440×400, open wordmark)

### Other
- `assets/legacy_pulse_logo_500.png` — the original logo. Retire it and delete `assets/pulse_500x500_logo.png` from the app.
- Icons: the design uses **text + geometric glyphs** (■ ▶ ↻ ← ● ✓ ▲) instead of an icon set. If icons are needed, use a sharp, square-cornered set (e.g. Material Symbols Sharp, weight 600).
- Map tiles: OpenStreetMap via flutter_map, grayscale filter.

## Files
- `screens/Wire 0 - Palette.dc.html` — light/dark palette, type scale, rules, buttons
- `screens/Wire 1 - Ping.dc.html` — 01 Live, 02 Configure, 03 History
- `screens/Wire 2 - Network.dc.html` — 04 Network info, 05 LAN scan, 06 Geo IP
- `screens/Wire 3 - Diagnostics.dc.html` — 07 Tools hub, 08 Traceroute, 09 Port scan, 10 Speed test, 11 Packet loss
- `screens/Wire 4 - Monitor and Settings.dc.html` — 12 Monitor, 13 Alerts, 14 Settings
- `screens/Wire 5 - Brand.dc.html` — mark, lockups, platform icons, splash screens
- `screenshots/` — PNG of every screen (desktop 1280×800 @1x, mobile 390×844 @2x) + splash screens
- `screens/support.js` — runtime needed to open the HTML files
- `tokens/` — colors.json, tokens.css, wire_theme.dart
- `CLAUDE_CODE_PROMPT.md` — paste-ready prompt for Claude Code
