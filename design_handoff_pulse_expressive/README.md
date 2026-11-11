# Pulse redesign kit: "Expressive" (Material 3 Expressive, plum / pink / lime)

This folder is the complete handoff for redesigning the **Pulse** Flutter app (network tools: ping, traceroute, port scan, speed test, packet loss, LAN scan, Geo IP, monitor, history, settings). It targets a coding agent such as Claude Code, so everything is explicit and machine-readable.

**Start here, then read in this order:**
1. `DESIGN_SYSTEM.md` covers colors (light + dark), type, shapes, components, patterns and motion.
2. `SCREENS.md` gives the spec for every screen, phone and tablet: layout, data, states and animations.
3. `screenshots/` is the visual target, 14 screens × phone/tablet × light/dark (56 PNGs).
4. `animations/` has MP4 clips showing how the motion should feel.
5. `tokens/` has drop-in Flutter code: theme, shapes, wavy progress, animated logo, motion helpers.

---

## Folder map

| Path | What it is |
|---|---|
| `screenshots/phone/{dark,light}/NN-*.png` | 390×844 pt @2x phone screens |
| `screenshots/tablet/{dark,light}/NN-*.png` | 1280×800 pt @1.5x landscape tablet screens |
| `screenshots/_overview-*.png` | Contact sheets of all screens |
| `animations/*.mp4` | Screen recordings of the live prototype (motion reference) |
| `logo/svg/` | Logo A "Heartbeat Cookie": mark, mono, app icon, adaptive layers, lockups, outlined wordmark, animated SVG |
| `logo/png/ios/` | iOS AppIcon PNGs (opaque, square), 20–1024 |
| `logo/png/android/` | Play Store 512, adaptive foreground / background / monochrome (432 px), legacy mipmaps, Android 12 splash icon |
| `logo/png/brand/` | Mark, lockups, stacked logo, wordmark PNGs |
| `fonts/RobotoFlex-Variable.ttf` | Roboto Flex variable font (all axes) + `OFL.txt` license |
| `assets/icons/*.svg` | 52 stroke icons (24 px grid, 2.2 px stroke, `currentColor`) |
| `assets/shapes/*.svg` | M3 Expressive shape family (cookie 4/7/9/12, clover 4/8, sunny, burst, flower, arch, pill, diamond, slanted, square, circle) + wavy ring |
| `assets/map/` | Styled South/Southeast Asia map with the Dhaka → Singapore route (reference for Geo IP styling) |
| `tokens/tokens.json` | All design tokens, machine-readable |
| `tokens/pulse_theme.dart` | `buildPulseTheme(Brightness)`: ColorSchemes, TextTheme, component themes, `PulseTokens` extension |
| `tokens/pulse_shapes.dart` | `PulseShape`, `PulseShapeBorder`, `PulseShapeBox` (spinning hero), `WavyProgress`, `PulseLogo` |
| `tokens/pulse_motion.dart` | Curves, durations, springs, `PulseEntrance`, `PulsePressable`, `PulseLiveValue`, `PulseLiveDot` |
| `prototype/` | The HTML prototype everything was rendered from (open `prototype/index.html`) |

## Viewing the prototype

Open `prototype/index.html` in Chrome:
- `index.html?device=phone&theme=dark` shows a gallery of every phone screen (also `tablet`, `light`)
- `index.html?screen=speed&device=phone&theme=light` shows one screen, live (numbers tick, shapes animate)
- Screen keys: `splash ping pingDetail network tools trace ports speed loss lan geo monitor history settings`

The prototype is the source of truth for exact spacing and sizes. `prototype/phone.js` and `prototype/tablet.js` are readable HTML templates, one function per screen. `prototype/styles.css` holds the tokens as CSS variables.

Re-render screenshots: `node prototype/tools/render.cjs screenshots` (needs Playwright). Re-record clips: `node prototype/tools/record.cjs animations-raw`.

---

## Implementation plan for the agent

Do these in order and keep each step compiling.

1. **Fonts.** Copy `fonts/RobotoFlex-Variable.ttf` to `assets/fonts/` and register it:
   ```yaml
   flutter:
     fonts:
       - family: RobotoFlex
         fonts:
           - asset: assets/fonts/RobotoFlex-Variable.ttf
   ```
   Weight and width come from `FontVariation('wght'|'wdth', …)` (already done in `pulseText()`). Always keep tabular figures for numbers.
2. **Theme.** Copy `tokens/pulse_*.dart` to `lib/theme/`. Wire `theme: buildPulseTheme(Brightness.light)`, `darkTheme: buildPulseTheme(Brightness.dark)` and `themeMode` from settings (Light / Dark / System). Remove every hard-coded color and `TextStyle` in the app. Use `context.colors`, `context.type`, `context.pulse.latencyColor(ms)`.
3. **Icons and logo.** Use `flutter_launcher_icons` with the files in `logo/png/` (config below). Use `PulseLogo` for the in-app splash and the tablet rail brand. Use `flutter_native_splash` for the OS splash.
4. **App shell.** Use adaptive navigation. Below 600 dp wide, show a `NavigationBar` with 4 tabs: Ping, Network, Tools, History. From 600 dp, show a `NavigationRail` (96 dp) with the brand mark, a "+" button, the same 4 destinations, and Settings pinned at the bottom. From 840 dp, tool screens use list-detail: a 300 dp Tools pane plus content. Ping detail and History also use list-detail (see `SCREENS.md`).
5. **Shared widgets** (see `DESIGN_SYSTEM.md` → Components): hero cookie metric, segmented list, connected button group, stat row, shape badge, pill bar sparkline, wavy progress (linear and circular), live value, live dot, tool tile, search field. Build these before the screens.
6. **Screens.** Follow `SCREENS.md` one screen at a time and compare against the PNG for each theme and device. Keep all existing networking logic. This is a visual and interaction redesign, not a rewrite of the engine.
7. **Motion pass.** Add entrances, press feedback, ambient loops and live-value transitions per the motion table. Check that system "remove animations" turns ambient loops off.
8. **QA.** Check both themes and both form factors. Text contrast must be ≥ 4.5:1 and touch targets ≥ 48 dp. Test the "no data / error / running / done" states listed per screen.

### Launcher icons (`pubspec.yaml`)
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/brand/AppIcon-1024.png"            # from logo/png/ios/AppIcon-1024.png
  remove_alpha_ios: true
  adaptive_icon_background: "#4A1D3B"
  adaptive_icon_foreground: "assets/brand/ic_launcher_foreground.png"     # logo/png/android/adaptive/
  adaptive_icon_monochrome: "assets/brand/ic_launcher_monochrome.png"     # Android 13 themed icon
```
### OS splash (`flutter_native_splash.yaml`)
```yaml
flutter_native_splash:
  color: "#FFF7FA"
  color_dark: "#19121D"
  image: assets/brand/pulse-mark-512.png               # logo/png/brand/
  android_12:
    image: assets/brand/android12-splash-icon-1152.png # logo/png/android/
    color: "#FFF7FA"
    color_dark: "#19121D"
```
Then hand off to an in-app splash that shows the animated `PulseLogo` (see `animations/01-logo-splash-phone-dark.mp4`) while monitors start.

### Prompt you can paste into Claude Code
> Read `pulse-kit/README.md`, `DESIGN_SYSTEM.md` and `SCREENS.md`. Redesign this Flutter app to match the screenshots in `pulse-kit/screenshots/` for phone and tablet in light and dark. Start with fonts, theme (`pulse-kit/tokens/*.dart`), launcher icons and the adaptive shell, then shared widgets, then screens in SCREENS.md order. Don't change networking logic. After each screen, compare against its PNG and list any differences you couldn't match.

---

## Notes and limits
- The Dart files were written for Flutter ≥ 3.27 but were **not compiled here**, because there's no Flutter SDK in this environment. Expect small fixes (an API name, a lint).
- Material 3 Expressive components such as the wavy progress indicators, connected button groups, shape morphs and the expressive motion scheme aren't all in Flutter core yet, so `pulse_shapes.dart` / `pulse_motion.dart` implement the needed pieces with plain Flutter. The spring values are approximations of the M3 Expressive scheme.
- Geo IP map: the screenshots use a Natural Earth vector render. In the app, use a real map (for example `flutter_map`) with a muted, label-free style tinted to `PulseTokens.map*`, and show the tile provider's attribution. Check that provider's terms.
- MAC addresses are hidden by Android/iOS for privacy; the UI explains this rather than showing an error.
- Sample data comes from the current app's screenshots (Nov 2026).
