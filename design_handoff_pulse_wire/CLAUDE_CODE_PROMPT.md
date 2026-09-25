# Prompt for Claude Code

Copy everything below the line into Claude Code, run from the root of the `pulse` repo, with this `design_handoff_pulse_wire/` folder placed in the repo root.

---

You're redesigning **Pulse**, my Flutter network-diagnostics app (Windows, macOS, Linux, Android, iOS). I want a complete visual overhaul to a new design language called **Wire**. The full spec is in `design_handoff_pulse_wire/README.md`. Read it end to end first. The HTML files in `design_handoff_pulse_wire/screens/` are high-fidelity **design references** (open them in a browser). Recreate them in Flutter; don't port the HTML. `design_handoff_pulse_wire/screenshots/` has a PNG of every screen for quick visual reference.

**What Wire is:** a bold, hard-edged grid UI. Every panel, row, button and nav item sits on 2px ink borders with **zero border radius** and no blur shadows. Headlines and numbers use heavy condensed **Archivo** (variable font, wdth 62–80, weight 800–900, uppercase). Data and labels use **Space Mono**. There is a single accent, **Signal orange #E8612C** (from the original logo), used only for live values, spikes, primary actions and incidents. The light theme is "Paper" (#F2F0EB bg / #111111 ink). The dark theme "Ink" is a strict inversion that keeps the orange.

**Do this in order, committing after each step:**

1. **Foundation**
   - Add `design_handoff_pulse_wire/tokens/wire_theme.dart` as `lib/core/theme/wire_theme.dart`.
   - Bundle the Archivo variable TTF and Space Mono 400/700 under `assets/fonts/` and register them in `pubspec.yaml`.
   - Replace the flex_color_scheme + Fira Code setup in `lib/main.dart` with `buildWireTheme(Brightness.light/dark, accent: …)`. Keep ThemeMode persistence in SharedPreferences, and add accent persistence.
   - Remove `flex_color_scheme` once nothing uses it.
2. **Wire primitives** in `lib/core/widgets/wire/`: `WireBox` (2px border container), `WireCell`, `WireRow` (1px hairline list row with optional highlight), `WireSegmented`, `WireToggle` (square switch), `WireButton` (primary signal / inverse ink / outline), `WireStat` (label + big condensed value), `WireBarChart` (spike threshold coloring, gridlines), `WireStatusStrip` (N cells), `WireProgress`, `WireHeroNumber` (value + signal unit suffix), `WireCopyButton` (COPY → COPIED 1.2s).
   - Use `context.wire` for every color. No hard-coded hex values outside the theme file.
3. **Adaptive shell.** Replace the current bottom-navigation / side-navigation layout in `lib/presentations/navigation/`:
   - ≥1024px: 220px numbered sidebar (12 destinations, see README) + 64px top bar, with the orange PULSE logo cell top-left and the connection footer.
   - 600–1023px: compact rail.
   - <600px: bordered content container + 4-cell bottom tab bar (PING / NET / TOOLS / HISTORY), with a mobile Tools hub.
   - Update go_router routes for every screen.
4. **Screens**, one per commit, matching README §Screens and the HTML exactly: 01 Ping Live, 02 Configure (desktop side panel / mobile bottom sheet), 03 History, 04 Network info, 05 LAN scan, 06 Geo IP (flutter_map, grayscale OSM, square markers), 07 Tools hub, 08 Traceroute, 09 Port scan, 10 Speed test, 11 Packet loss, 12 Monitor, 13 Alerts, 14 Settings.
   - Reuse the existing logic in `ping_screen.dart`, `network_screen.dart`, `diagnostics_screen.dart` and `tools_screen.dart` where it works. Move logic into Riverpod providers (see README §State) so widgets stay presentational.
   - Screens that have no backend yet (LAN scan, Monitor, Alerts, Geo IP, Packet loss) should still be fully built, with the provider stubbed behind a clear TODO.
5. **States:** implement the empty, loading/progress, error ("UNREACHABLE") and hover/pressed/focus states described in README §Interactions.
6. **Dark mode pass:** check every screen in the Ink theme. Borders and inverse fills must flip, and text on orange is always #111111.
7. **Brand everywhere** (README §Brand & Assets):
   - Copy `design_handoff_pulse_wire/assets/` to `assets/brand/` and register it in pubspec.
   - Replace `flutter_launcher_icons.yaml` with the config in the README, then run it (this covers Android adaptive + monochrome, iOS light/dark, macOS, Windows .ico and web).
   - Add `flutter_native_splash` with the README config and run it.
   - Build a desktop launch route matching `assets/splash/splash_desktop_window.png`.
   - Use the bolt mark in: the sidebar logo cell, About/Settings footer, empty states, the Android notification small icon, the desktop tray/menu-bar icon, the window icon, and the web favicon/manifest (theme_color #E8612C).
   - Add a reusable `PulseMark` widget (flutter_svg, colourways primary/dark/mono, auto-drops the offset below 32px) and a `PulseLockup` widget.
   - Delete the old `assets/pulse_500x500_logo.png` and update the README screenshots in the repo with `design_handoff_pulse_wire/screenshots/`.

**Rules:**
- No `BorderRadius` other than zero.
- No Material elevation or shadows, apart from the optional hard `12,12,0` offset on desktop cards.
- Uppercase condensed Archivo for titles, nav, buttons and numbers; Space Mono for everything else.
- Orange only for meaning, never decoration.
- Keep hit targets ≥44px on mobile.
- Run `flutter analyze` clean after each step.

Before you start coding, summarize your understanding of the design system and give a short plan of the file changes. Then go.
