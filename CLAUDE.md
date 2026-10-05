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

### Progress
All seven steps are done (see `git log`). Every screen 01–14 is rebuilt on real engines; no legacy screens remain.
- Engines: `lib/services/net/` (ping prober + Windows ICMP FFI, traceroute, port scanner, speed test, LAN scan with
  ARP/NetBIOS/mDNS/OUI, Wake-on-LAN, geo IP, per-OS network details, gateway), `lib/services/background/`
  (MonitorEngine, notifications, foreground service), `lib/services/desktop/` (window + tray, launch at login).
- Providers: `lib/providers/*` (one per tool; `pingBoardProvider` = multi-ping; `monitorRunnerProvider` decides where
  monitoring runs: tray on desktop, foreground service on Android/iOS when "Run in background" is on, else in-app).
- DB schema v2 (saved_targets + sessions.label). Bump `schemaVersion` + add an `onUpgrade` step for changes.

### Test checklist for real devices (office PC: Android phone + Windows)
- Android: install `flutter run` → allow notifications; Network screen asks for location (needed for SSID);
  Monitor → add a target → Settings › Monitor › Run in background → a "Pulse · monitoring" notification should stay;
  kill the app, targets keep being checked; alert rules notify. LAN scan on Android cannot read MACs (OS limit).
- Windows: closing the window hides to the tray (tray menu: Show / Pause / Quit); launch at login (Run key for the
  plain build, StartupTask for the MSIX) starts hidden with `--autostart`; the first launch shows the 720×440 launch
  window then grows to the app.
- Local MSIX on this PC: signed with a per-machine self-signed cert `CN=Pranta Dutta` stored in
  `%USERPROFILE%\.pulse-signing\` (pfx + password.txt, user-only ACL; public .cer trusted in LocalMachine\TrustedPeople).
  Rebuild: `dart run msix:create --certificate-path %USERPROFILE%\.pulse-signing\pulse_local.pfx --certificate-password
  <password.txt> --publisher "CN=Pranta Dutta" --install-certificate false`, install with Windows PowerShell 5.1
  `Add-AppxPackage` (the Appx module does not load in PowerShell 7). Never trust msix's bundled test_certificate.pfx —
  its private key is public.
- iOS/macOS were not built on this machine (Windows). On a Mac: `flutter build ios` / `macos`; iOS needs the
  "Access Wi-Fi Information" capability enabled in Xcode for the SSID. `ios/Podfile` already defines the
  permission_handler macros. macOS runs un-sandboxed (system tools) — see `macos/Runner/*.entitlements`.

## Microsoft Store (Windows MSIX)
- Packaging: `dart run msix:create` (config in `pubspec.yaml` › `msix_config`). Output: `build/windows/x64/runner/Release/pulse.msix`.
  Local builds are signed with the msix tool's test certificate; Store builds use `dart run msix:create --store`
  (unsigned — the Store signs it).
- Launch at login inside the package uses the manifest StartupTask (`startup_task`, id `PulseStartup`) via the runner's
  C++/WinRT channel (`windows/runner/startup_task.cpp`); unpackaged builds keep the HKCU Run key. Windows only lets the
  user re-enable a task they switched off in Task Manager › Startup apps.
- Toast activation: `toast_activator.clsid` must equal the `guid` in `lib/services/background/notifications.dart`.
- Version: `msix_version` must end in `.0` for the Store; keep it in step with `version:` (currently 2.0.0 / 2.0.0+2).
- Policies (Store listing): https://legal.pranta.dev/pulse/privacy and https://legal.pranta.dev/pulse/terms, served
  from `G:\MyProjects\privacy-project\Projects\pulse\` (push to master → auto-deploys).
- STILL NEEDED from the user: a Partner Center account and the reserved app name; then copy Package/Identity/Name →
  `identity_name`, Package/Identity/Publisher (CN=…) → `publisher`, PublisherDisplayName → `publisher_display_name`,
  set `display_name` to the reserved name, and add that name to `displayNames` in privacy-project `Program.cs` if it
  differs from "Pulse". Store listing also needs screenshots, description and age rating (done in Partner Center).

## Verifying
- `flutter analyze` must be clean. `dart format` uses page width 120 (analysis_options.yaml).
- `flutter test` — `test/render/*` (tag `render`) writes PNG renders to `build/renders/` with real fonts;
  `test/services/*_live_test.dart` (tag `network`) hits the real network.
- Windows build needs the Visual Studio component **"C++ ATL for latest v143 build tools"** (for
  `flutter_local_notifications_windows`).
- The user continues on the office PC with an Android device + Windows PC — run on both there.
