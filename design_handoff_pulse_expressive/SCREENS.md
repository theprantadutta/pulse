# Screen specs

Each screen lists its screenshots, its phone layout from top to bottom, its tablet layout, its data, its states and its motion. Sizes are in logical px. Exact markup lives in `prototype/phone.js` and `prototype/tablet.js`, one function per screen with the same key. Component names refer to `DESIGN_SYSTEM.md` §8.

**Information architecture**
- Phone: bottom navigation with **Ping · Network · Tools · History**. Settings opens from the Tools app bar (gear). Tool screens push from the Tools hub with a back arrow, and the Tools tab stays selected.
- Tablet: navigation rail with brand, "+" (new ping), **Ping · Network · Tools · History**, and Settings at the bottom. Tool screens show the **Tools pane** (all 8 tools with their last result) next to the content, which replaces the old numbered 01–12 rail.
- The old phone "PING" tab (multi-host list) and the single-host screen become **Ping** (home) and **Ping detail**.

---

## 01 Splash (`splash`)
Screenshots: `*/01-splash.png` · Clip: `animations/01-logo-splash-phone-dark.mp4`, `00-logo-loop.mp4`
- **Phone:** centered column. `PulseLogo(size: 168, animated: true)` pops in (700 ms spring), then the wordmark "Pulse" (52/800 wdth 125) and the tagline "Network tools that feel alive" (15, onSurfaceVariant) rise in at 350 ms delay. At the bottom (64 from the edge): a wavy linear progress 160 wide at the real start-up progress, labeled "Starting monitors…".
- **Tablet:** the same centered composition with no rail: logo 220, wordmark 72, progress 220.
- **Behaviour:** show for as long as initialisation takes, with a minimum of ~900 ms so the heartbeat completes once, then cross-fade to Ping. The OS splash (flutter_native_splash) shows the static mark first.

## 02 Ping, home (`ping`)
Screenshots: `*/02-ping.png` · Clips: `02-ping-home-phone-*.mp4`, `08-ping-grid-tablet-*.mp4`
- **Phone:**
  1. Large app bar "Ping" (headlineLarge) with actions: tonal "Pause all" icon button and a "Ping settings" icon button (tune).
  2. Host chips (horizontal scroll). The selected host is a filled chip with a check. Selecting a chip changes the hero.
  3. **Hero metric** for the selected host: cookie12 220 px with a live dot and host IP, latency in displayLarge, and a morphing blob behind.
  4. **Stat row**: Avg · Max · Loss (tertiary when 0%) · Jitter.
  5. "Other hosts" label, then a segmented list of the remaining hosts. Each row has a lead badge (router = circle tertiaryContainer, Cloudflare = arch secondaryContainer, GitHub = cookie9 primaryContainer), name, IP or "2.3% loss · host" in latSlow, and a live latency value.
  6. FAB "Stop all" (pink). When stopped it becomes "Start all".
- **Tablet:** rail (Ping). Header "Ping" with "6 hosts live · every 1 s · 0.6% loss overall". Actions: tonal "Pause all", pink large "Add host". Below is a 3 × 2 grid of host cards (surfaceContainer, radius 28); the hero host is in secondaryContainer. Each card shows: lead badge, name and host, a spinning cookie9 status (latFast when no loss, latSlow when loss), latency at 68/900, a loss pill (lime "0% loss" or pink "2.3% loss"), a 24-bar sparkline, and "Avg · Max · Jitter · N sent".
- **Data:** per host: name, host, last RTT, avg, max, jitter, loss %, sent, last 24–60 samples. Tapping a card or row opens Ping detail.
- **States:** no hosts shows an empty state ("Add a host to start pinging" with an Add host button and suggested hosts as chips: Router, 1.1.1.1, 8.8.8.8). A host that is down shows the value "—", the status cookie in error color, and the text "No reply for 30 s".
- **Motion:** hero spin and breathe, blob morph, chip pop, row entrance stagger, bar grow, live values.

## 03 Ping detail (`pingDetail`)
Screenshots: `*/03-ping-detail.png` · Clip: `09-ping-detail-tablet-dark.mp4`
- **Phone:**
  1. App bar with back, title "Google DNS", subtitle "8.8.8.8", and actions tune and more.
  2. A row with the hero cookie (176) showing "Live" and "37 ms", and on the right a "No loss" lime pill plus settings and summary text.
  3. Card "Last 30 pings": a 30-bar sparkline (max 100 ms) with a dashed average line and "30 s ago / now" labels.
  4. Stat row: Avg · Loss · Max (latSlow) · Jitter.
  5. Setting chips: 1 s · 56 B · Timeout 2 s · Alert. Tapping one opens a bottom sheet.
  6. Buttons: pink large "Stop" and a tonal share button.
- **Tablet (list-detail):** rail (Ping) plus a **Hosts pane** (340): title "Hosts" with a pause button, a segmented list of all hosts (the selected one fully rounded in secondaryContainer), and "Add host" at the bottom. The detail area has a headlineLarge host name, the hero cookie 260 with the blob, pills (No loss · Jitter · Every 1 s · 56 B), a 2 × 2 stat grid (Average, Loss, Max, Min), a "Last 60 pings" chart (150 tall, with a legend for the latency bands), and a footer of setting chips plus a pink "Stop".
- **States:** paused shows a "Paused" pill in outline style, the hero stops spinning and the value dims to onSurfaceVariant. Loss spikes show as pink dots in the chart.

## 04 Network (`network`)
Screenshots: `*/04-network.png`
- **Phone:**
  1. Large app bar "Network" with a tonal refresh button.
  2. **Pink hero card** (radius 32, 172 tall) with a spinning decorative cookie: "Connected · Wi-Fi 4 · 2.4 GHz", SSID at 52/900 wdth 125, and pills "−56 dBm · Good" (inverted) and "Link 52 Mb/s".
  3. Segmented list: Local IPv4, Subnet, Gateway, DNS 1 (each with a copy button), DNS 2, MAC address ("Hidden by Android" with an info button) and IPv6 ("Not assigned").
  4. FAB "Scan network", which opens LAN scan.
- **Tablet:** rail (Network). The left column (540) holds the hero card (250 tall, SSID at 84), a Signal tile (4 rising bars plus "−56 dBm") and a Link speed tile (sunny badge), and a lime "Who's on this network?" card with "Scan network". The right column holds the full details segmented list.
- **States:** on mobile data, the hero switches to "Mobile data · LTE" with the carrier name, and the Wi-Fi-only rows hide. Offline shows an errorContainer hero "No connection" with an "Open settings" button. Signal labels: ≥ −60 Good, −60 to −70 Fair, < −70 Weak (bars 3/2/1).

## 05 Tools hub (`tools`)
Screenshots: `*/05-tools.png` · Clip: `05-tools-entrance-phone-dark.mp4`
- **Phone:** large app bar "Tools" with a Settings gear. A 2-column grid of 8 **tool tiles** (138 tall): badge, name, last result. Monitor is pink with a "LIVE" dot while monitoring runs. Order: Ping, Traceroute, Port scan, Speed test, Packet loss, LAN scan, Geo IP, Monitor.
- **Tablet:** a 4 × 2 grid of large tiles (badge 72, name 28, chevron).
- **Data:** each tool's last result string (e.g. "21 hops · BD → SG", "9.4 ↓ · 7 ↑ Mbps"). Show "Not run yet" when there is none.
- **Motion:** tiles enter with a 40 ms stagger. Press morph on tap.

## 06 Traceroute (`trace`)
Screenshots: `*/06-traceroute.png` · Clip: `04-traceroute-phone-dark.mp4`
- **Phone:**
  1. App bar "Traceroute" with a pink "Run again" icon button.
  2. Target field "github.com" with the resolved IP on the right.
  3. A summary row: "56" (displayMedium) with "ms to reach", and pills "21 hops" (lime) and "BD → SG" (lavender).
  4. **Route rail** card: "Route · 10 timeouts".
  5. "Highlights" with "See all 21", which shows the full hop list. The highlights are a segmented list of the first hop, the biggest local spike, timeouts, the biggest jump ("+55 ms" pink pill) and the destination.
- **Tablet:** rail, Tools pane (Traceroute selected), then content:
  - Header: title, target field (with "max 30 hops · 3 probes"), pink "Run again".
  - Left: the full hop list as a segmented list. Each row has hop number, latency dot, host with "ip · probe1 / probe2 / probe3 ms" underneath, a zone pill (LAN/ISP/BD/SG) and the RTT. Timeouts are grouped as "No reply · 09–10". Transit hops collapse into "Transit · hops 11–20" with a "+55 ms jump" pill and a chevron. The destination row is selected.
  - Right (300): a "Destination reached" card (56 ms, pills), the route rail card, a primaryContainer "Biggest jump" explanation card, and Copy / Save buttons.
- **Highlight rules:** the biggest jump is the largest RTT increase between consecutive replying hops. A local spike is a hop more than 2× its neighbours. Zones come from private-range detection (LAN), ASN/hostname (ISP), and the Geo IP country code.
- **States:** while running, hops pop in as they resolve (node pop), the wavy progress shows under the field, and "Run again" becomes "Stop".

## 07 Port scan (`ports`)
Screenshots: `*/07-port-scan.png` · Clip: `10-port-scan-tablet-dark.mp4`
- **Phone:**
  1. App bar with a pink play button (Scan).
  2. Target field with the resolved IP.
  3. Connected group: Common · 1–1024 · Custom (Custom opens a range sheet).
  4. Three shape stats: Open (cookie9 pink), Filtered (clover4 lavender), Time (square lime).
  5. Port map card (22 × 3 cells for common ports) with a legend.
  6. Results segmented list: port number (22/900), service and banner, and an Open (pink) or Filtered (outline) pill.
- **Tablet:** header plus Scan button. A row with the field and the group (1–1024 selected). Four stat cards (Scanned 1024, Open 2, Filtered 1, Time 4.9 s). A full-width port map card (32 × 8 cells of 21 px, "each cell = 4 ports · 128 connections"). The results list below.
- **States:** while running, cells fill in scan order with a cell pop, the counters tick, and Scan becomes Stop. Port 0-results shows "No open ports found" with the scanned range.

## 08 Speed test (`speed`)
Screenshots: `*/08-speed-test.png` · Clips: `03-speed-test-phone-*.mp4`
- **Phone:**
  1. App bar with an outlined server chip "Cloudflare · DAC". Tapping it opens server selection.
  2. Connected group of phases: "✓ Ping 37" (done, tertiary) · **Download** (selected, pink) · Upload.
  3. **Wavy circular gauge** 280, at 36% of the ring for 9.4 Mbps on a log scale: label "Download", number 92/900, unit "Mbps".
  4. "Measuring download · 6.2 s" with a wavy linear progress for phase progress.
  5. Shape stats: Ping 37 (clover4 lime, wobble), Jitter 27 (sunny lavender, spin), Upload pending (dashed arch, "next").
  6. Tonal large "Cancel test".
- **Tablet:** left: the phase group, the 400 px gauge, and phase progress with "log scale 1–500 Mbps". Right (300): Ping and Jitter shapes, a dashed "Upload · starts after download" card, and "Past results" (time, server and ping, ↓ and ↑).
- **States:** idle shows the gauge empty with a large pink "Start" button in the center. Done shows the gauge holding the download value, a result summary card (↓ 9.4 · ↑ 7.1 · ping 37 · jitter 27), and "Run again" / "Share".
- **Gauge math:** `value = log(max(mbps, 1)) / log(500)`, clamped to 0–1.

## 09 Packet loss (`loss`)
Screenshots: `*/09-packet-loss.png` · Clip: `07-packet-loss-phone-dark.mp4`
- **Phone:**
  1. App bar with a tonal "Stop".
  2. Target field "1.1.1.1" with "5 min · 1/s".
  3. A row with the burst hero (170, spinning) showing "Loss 2.2%", next to an "Unstable" lavender pill and a one-sentence verdict.
  4. Stat row: Sent · Lost (latSlow) · Late · Longest burst.
  5. "Elapsed 1:29 of 5:00 · 30%" with wavy linear progress.
  6. Timeline card: 30 × 10 cells.
- **Tablet:** header (field, duration and rate chips, pink Stop). A row with the burst 230 plus a pill, an 18 px verdict paragraph, and a 4-stat row. Progress across the full width. A timeline card (60 × 5 cells). A "Round-trip time" bar chart (one bar per packet; lost packets as dots). Actions: Export CSV, Alert on loss, Compare with 8.8.8.8.
- **Verdict rules:** 0% is "Stable" (lime): "No loss and latency is steady". Below 1% with single drops is "Mostly stable". Up to 5% or isolated drops is "Unstable" (lavender): "Drops are isolated single packets…". Above 5%, or bursts of 3 or more, is "Degraded" (pink): "Bursty loss, likely a congested or failing link". Late means RTT above 150 ms.

## 10 LAN scan (`lan`)
Screenshots: `*/10-lan-scan.png`
- **Phone:**
  1. App bar "LAN scan" with subtitle "192.168.0.0/24 · 254 hosts" and a pink rescan button.
  2. Summary card: clover4 lime "3" (wobble), "Devices found", "Scan complete · 254 of 254 · 21.6 s", and a complete (lime) wavy bar.
  3. Filter chips: All 3 · Router · Phones · Unknown · ICMP + TCP.
  4. An expanded card (secondaryContainer) for the selected device: icon, "Router" with a Gateway badge, IP, RTT; a 2 × 2 grid of Hostname, Vendor, MAC, First seen; open-port pills; and actions Ping (pink), Ports, Wake (disabled when there's no MAC).
  5. A segmented list of the other devices ("This device", "Unknown device" with a dashed help icon).
- **Tablet:** header plus "Scan again". The summary card spans the full width. Left (330): chips and the device list (selected = Router). Right: a large secondaryContainer detail panel with the IP at 30/900, the details grid, open ports with service names, and actions Ping / Scan ports / Wake on LAN.
- **States:** scanning shows a live counter "142 of 254" with the wavy bar and devices popping into the list as found. Wake is enabled only when the MAC is known.

## 11 Geo IP (`geo`)
Screenshots: `*/11-geo-ip.png` · Clip: `06-geo-ip-route-phone-dark.mp4` · Map reference: `assets/map/`
- **Phone:**
  1. App bar with a text button "My IP".
  2. Lookup field "github.com" showing "20.205.243.166".
  3. **Map card** 358 × 250 with the route arc from "You · Dhaka" to Singapore, a travelling packet, and a sonar on the target.
  4. Place: "Singapore" (headlineLarge) with "SG · Asia/Singapore · UTC+8", and actions Ping this (tonal) and Trace route (pink).
  5. Pills: 2,887 km (lime) · 55 ms (lavender) · 19 hops.
  6. Segmented details: Org, ASN, Coordinates, Hosting.
- **Tablet:** header (field, My IP, pink Locate). A tall map (450 × 668) on the left. On the right: a pink "Located in Singapore" hero card, pills, the full details list (IP, City, Org, ASN, Coordinates, Postal, Hosting), actions, and the data-source note.
- **Implementation:** use a real map (e.g. flutter_map) with a muted style tinted to `PulseTokens.mapSea/mapLand/mapBorder`. Draw the arc as a quadratic bezier offset 90 px perpendicular to the midpoint. Show attribution as the tile provider requires. Distance uses haversine between the device's public-IP location and the target.

## 12 Monitor (`monitor`)
Screenshots: `*/12-monitor.png`
- **Phone:**
  1. App bar with a pink "Add" small button.
  2. Status strip: live dot (tertiary), "Running · 6 targets", and a tonal "Pause".
  3. A row with the uptime cookie12 lime 150 ("Uptime 24h 100%") and a stacked stat column (Avg latency 42 ms, Incidents 0, Checks 13).
  4. Range group: 24 h · 7 d · 30 d.
  5. Targets segmented list: host and name with uptime %, a 24-block uptime strip (latest block solid, earlier at 45%), and the current latency.
- **Tablet:** header (status strip, range group, pink "Add target"). Stats row (uptime cookie plus 3 cards). Below, the targets list (36 blocks) on the left and an **Incidents** card on the right: empty state with a lavender flower and check, "No incidents", and helper text. When incidents exist, show a list of them (time, host, type: outage / loss / latency spike, duration).
- **Behaviour:** runs in the background (WorkManager / BGTaskScheduler). A block is red (latSlow) if any check in that slot failed, or lavender if latency was above 2× the baseline.

## 13 History (`history`)
Screenshots: `*/13-history.png`
- **Phone:**
  1. Large app bar "History" with search and export actions.
  2. Type chips: All · Ping · Trace · Speed · Ports · LAN · (Geo · Loss).
  3. Day header "Today · 9 runs".
  4. Segmented list. Each row has a type badge (same shape and color as its tool), the target, "time · tool · detail", and the result on the right.
- **Tablet (list-detail):** rail (History) plus a pane (420): title, export, filter field, chips, day header and list (the selected row is fully rounded). The detail shows the run: badge plus title "github.com" with "Traceroute · Today 16:30 · from AUT-SYS Wi-Fi", share and delete. Then a connected row of 4 summary tiles (Total 56 ms pink, Hops 21 lime, Route BD → SG lavender, Timeouts 10), the route rail, highlights, and "Run again" / "Copy as text". Other run types reuse their tool's summary components.
- **Export:** CSV and JSON, all or filtered.

## 14 Settings (`settings`)
Screenshots: `*/14-settings.png`
- **Phone:** app bar "Settings" with back. Section labels are 14/600 in primary.
  - *Appearance*: Theme (connected group Light · Dark · System), Dynamic color switch ("Use wallpaper colors (Android 12+)"), Accent picker (4 shapes: pink cookie (default), lavender clover, lime sunny, blue flower), Expressive motion switch.
  - *Ping defaults*: Interval 1 s, Packet size 56 bytes, Timeout 2 s (values in primary; tap to open a picker sheet).
  - *Monitor & alerts*: Notify on outage switch ("Loss over 5% or no reply for 1 min").
  - Then Notifications, Data & export, Privacy, and About (Pulse 2.0.0 · Apache-2.0 · Made with Flutter · Check for updates).
- **Tablet:** rail (Settings) plus a categories pane (Appearance, Ping defaults, Monitor, Notifications, Data & export, Privacy, About). Appearance detail: three **theme preview cards**, then Dynamic color, Accent and Expressive motion rows, and an About footer with the logo tile.
- **Behaviour:** Dynamic color on uses `DynamicColorBuilder` (dynamic_color package) for the scheme roles, but keeps the fixed brand roles and `PulseTokens` unchanged so shapes and charts stay on-brand. Accent swaps the fixed pink family for the chosen one (keep each "on" pairing at ≥ 4.5:1). Expressive motion off sets `disableAnimations` app-wide.

---

### Shared states checklist (every tool)
| State | Treatment |
|---|---|
| Idle / never run | Target field focused, primary action, "Not run yet" in Tools hub |
| Running | Wavy progress, live values, Stop/Cancel, results stream in |
| Done | Summary and verdict, Run again, Copy/Save/Share, saved to History |
| Error | errorContainer banner: cause plus retry (DNS failed, host unreachable, permission) |
| Offline | Global snackbar "You're offline", disable network actions |
