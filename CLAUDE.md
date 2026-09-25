# Pulse — project notes for Claude

## Current work: "Wire" redesign (branch `redesign/wire`)
Full visual + functional overhaul of Pulse to the **Wire** design language.

- **Spec:** `design_handoff_pulse_wire/README.md` (read end to end) and the original task prompt
  `design_handoff_pulse_wire/CLAUDE_CODE_PROMPT.md`. HTML references are in `design_handoff_pulse_wire/screens/`
  (open in a browser with `support.js` next to them); PNG of every screen in `design_handoff_pulse_wire/screenshots/`.
- The handoff folder is committed for reference only — the app uses the copies in `assets/brand/`,
  `assets/fonts/` and `lib/core/theme/wire_theme.dart`.
- **Do not** replace the repo's `screenshots/` folder with the handoff PNGs (those are design renders; real
  screenshots will be taken later).

### Decisions made with the user
- Persistence: **drift** (`lib/data/db/app_database.dart`, run `dart run build_runner build` after schema edits).
- **No stubs anywhere.** Every screen/provider must be fully real: LAN scan, Monitor, Alerts, Geo IP, Packet loss
  included. Full background work: Android foreground service (`flutter_foreground_task`), iOS WorkManager/BGTask,
  desktop system tray (`tray_manager` + `window_manager`, keep monitoring when window closes), local notifications
  on all platforms (`flutter_local_notifications`), launch-at-login implemented natively (the `launch_at_startup`
  package conflicts with `device_info_plus` 13).
- Always use the latest pub.dev versions (check pub.dev + changelogs).
- Commit after each step; no Claude / AI attribution in commit messages. Style: `feat: :sparkles: ...` (gitmoji).
- The app imports `package:material_ui/material_ui.dart` (decoupled Material), not `flutter/material.dart`.

### Progress (update as you go)
1. ✅ Foundation — Wire theme, fonts (Archivo variable, Space Mono, `WireGlyphs` fallback subset for ■▶↻●✓▲),
   settings provider (theme mode + accent persisted), drift DB.
2. ✅ Primitives — `lib/core/widgets/wire/` (barrel `wire.dart`), `PulseMark` / `PulseLockup` in `lib/core/brand/`.
3. ✅ Adaptive shell + go_router — `lib/presentations/navigation/` (`app_router.dart`, `wire_shell.dart`,
   `destinations.dart`), launch route, mobile Tools hub. Unbuilt routes still point at the legacy screens
   (`ping_screen.dart`, `network_screen.dart`, `diagnostics_screen.dart`, `tools_screen.dart`) until replaced.
4. ⏳ Screens 01–14, one commit each.
   - ✅ 01–03 Ping / Configure / History, **plus multi-ping** (user request): up to 32 concurrent named pings
     (`pingBoardProvider` in `lib/providers/ping_provider.dart`), board grid view, session strip, saved named
     targets (`SavedTargets` table, schema v2) with multi-select "PING SELECTED", names stored on History sessions
     (`Sessions.label`) and searchable. Engine: `lib/services/net/ping_prober.dart` (+ `windows_icmp.dart` FFI),
     `dns.dart`, `gateway.dart`; export via `lib/services/export_service.dart`.
   - Next: 04 Network info, 05 LAN scan, 06 Geo IP, 08–11 tools, 12 Monitor, 13 Alerts, 14 Settings
     (07 Tools hub already done). Remaining legacy screens: `network_screen.dart`, `diagnostics_screen.dart`,
     `tools_screen.dart` — delete each once its replacement lands, then drop syncfusion/stylish/material_symbols.
5. ☐ States (empty / loading / UNREACHABLE / hover-pressed-focus).
6. ☐ Dark-mode pass.
7. ☐ Brand everywhere (launcher icons, native splash, tray/window/notification icons, web manifest, delete
   `assets/pulse_500x500_logo.png`).

### Planned engine approach (for remaining tools)
- Traceroute: Windows FFI TTL probes; macOS `/usr/sbin/traceroute -n`; Linux `traceroute` → `tracepath` → TTL pings;
  Android/iOS TTL probes + direct ping of each hop for RTT.
- LAN scan: ICMP sweep + ARP table (`arp -a` / `/proc/net/arp` / `ip neigh`) + bundled OUI vendor list + reverse DNS;
  Wake-on-LAN via UDP broadcast. Android 10+ cannot read MACs of other devices (platform limit — show "—").
- Geo IP: ip-api.com (needs cleartext exception) with ipinfo.io fallback (`IP_INFO_TOKEN` in `.env`); flutter_map
  with grayscale OSM tiles and square markers.
- Speed test: Cloudflare (`speed.cloudflare.com/__down` / `__up`) plus Hetzner download servers.

## Verifying
- `flutter analyze` must be clean for new code (legacy screens carry pre-existing infos until deleted).
- `flutter test` — `test/render/*` (tag `render`) writes PNG renders to `build/renders/` with real fonts;
  `test/services/*_live_test.dart` (tag `network`) hits the real network.
- Windows build needs the Visual Studio component **"C++ ATL for latest v143 build tools"** (for
  `flutter_local_notifications_windows`).
- The user continues on the office PC with an Android device + Windows PC — run on both there.
