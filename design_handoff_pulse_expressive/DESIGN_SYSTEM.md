# Pulse design system: "Expressive"

Material 3 Expressive, tuned for a network-tools app. It uses a plum surface, a pink brand color, and lavender and lime as supporting brand colors, with Roboto Flex throughout. The values here are mirrored in `tokens/tokens.json`, `tokens/pulse_theme.dart` and `prototype/styles.css`.

## 1. Principles
1. **The number is the hero.** Every tool leads with one big, live value: latency, speed, loss or hop count. That value sits inside a brand shape.
2. **Color means something.** Lime means fast or good, lavender means medium, pink means slow, lost or "look here". Never use these three decoratively in data views.
3. **Explain the result.** Where a raw metric is ambiguous, add a short plain-language verdict ("Unstable: isolated single drops, mild congestion"; "Biggest jump: hop 08 → 11").
4. **Alive but calm.** Ambient motion (slow spins, travelling waves, live ticks) shows that the app is measuring. Motion is never needed to understand a screen, and it stops when the system's reduce-motion setting is on.

## 2. Color

### 2.1 Scheme roles
| Role | Dark | Light | Typical use |
|---|---|---|---|
| surface | `#19121D` | `#FFF7FA` | Screen background |
| surfaceContainerLowest | `#130D17` | `#FFFFFF` | |
| surfaceContainerLow | `#1F1724` | `#FCF0F5` | Map sea, bottom sheets |
| surfaceContainer | `#241B29` | `#F7EAF0` | Cards, list items, nav bar, tablet panes |
| surfaceContainerHigh | `#2F2535` | `#F1E4EA` | Search fields, stat tiles, tonal icon buttons, list items inside panes |
| surfaceContainerHighest | `#3A2F40` | `#EBDEE4` | Empty cells (timeline), map land |
| onSurface | `#F3E5F4` | `#21181E` | Primary text |
| onSurfaceVariant | `#D3C2D6` | `#524349` | Secondary text, inactive icons |
| outline | `#9C8BA0` | `#847379` | Timeout markers, switch outlines |
| outlineVariant | `#5E4F63` | `#D6C2CA` | Chip borders, closed port cells, dividers |
| primary | `#FFAFD0` | `#8E3A60` | Text buttons, accents in text, progress |
| onPrimary | `#5A1335` | `#FFFFFF` | |
| primaryContainer | `#7A2950` | `#FFD9E6` | Rail "+" button, "biggest jump" callout |
| onPrimaryContainer | `#FFD9E6` | `#3B0720` | |
| secondary | `#DDBCFF` | `#6B4F8A` | |
| secondaryContainer | `#4B3466` | `#F0DBFF` | Nav indicator, selected chip, selected list item, tonal button |
| onSecondaryContainer | `#F0DBFF` | `#25074A` | |
| tertiary | `#CDEB74` | `#4A6200` | "0% loss", success text |
| tertiaryContainer | `#3F5100` | `#CDEB74` | Router badge, success containers |
| onTertiaryContainer | `#E0F98A` | `#141F00` | |
| error / errorContainer | `#FFB4AB` / `#93000A` | `#BA1A1A` / `#FFDAD6` | Real failures only (host unreachable, permission denied) |
| inverseSurface | `#F3E5F4` | `#362D33` | Map "You" label, snackbars |

### 2.2 Fixed brand roles (same in both themes)
| Token | Hex | Pair | Use |
|---|---|---|---|
| pink (primaryFixedDim) | `#FFAFD0` | on `#3B0720` | Hero cookie, FAB, selected button in a group, Monitor tile, logo |
| lavender (secondaryFixedDim) | `#DDBCFF` | on `#25074A` | Secondary shapes (jitter, filtered, traceroute badge) |
| lime (tertiaryFixedDim) | `#CDEB74` | on `#141F00` | Success shapes (uptime, devices found, "21 hops" pill) |
| logo tile | `#4A1D3B` | heartbeat `#4A0F2C` | App icon only |

Brand shapes always use these fixed colors, which is why the hero cookie is the same pink on light and dark. Text on them uses the paired "on" color, never white.

### 2.3 Latency semantics (`PulseTokens`)
| Meaning | Threshold | Dark | Light |
|---|---|---|---|
| fast | < 10 ms | `#CDEB74` | `#4F6B00` |
| medium | 10–40 ms | `#DDBCFF` | `#72519C` |
| slow / lost | > 40 ms or lost packet | `#FFAFD0` | `#B0306A` |
| timeout | no reply | outline, dashed ring | outline, dashed ring |

Light-theme latency colors are darker so small dots and bars stay visible on a light surface. Use `context.pulse.latencyColor(ms)`; never pick these by hand.

## 3. Typography (Roboto Flex, variable)
| Flutter style | Size / weight / width | Use |
|---|---|---|
| displayLarge | 104 / 900 / wdth 120, lh .95, −4% | Live latency inside the hero cookie |
| displayMedium | 76 / 900 / 125, lh .9 | Summary numbers (traceroute total) |
| displaySmall | 56 / 900 / 120 | Tablet hero numbers, SSID on tablet |
| headlineLarge | 40 / 800 / 125 | Top-level titles: Ping, Network, Tools, History; "Singapore" |
| headlineMedium | 28 / 800 / 115 | Tablet pane titles, page titles in tool screens |
| titleLarge | 22 / 700 | App bar titles |
| titleMedium | 16 / 600 | List headlines, card titles |
| bodyMedium / bodySmall | 14 / 400, 13 / 400 | Body, supporting text |
| labelLarge | 14 / 700 | Buttons |
| labelMedium | 12 / 600 | Stat labels, nav labels |
| labelSmall | 11 / 700, +10%, UPPERCASE | Overlines |
| `pulseNumber()` | 20 / 800 / 110 | Trailing values in lists, stat values |

Rules: tabular figures on every number. "ms", "Mbps" and "%" units sit at about 20–25% of the number's size, bold, on the same baseline. Wide widths (115–125) are only for headlines and numbers; body text stays at wdth 100.

## 4. Shape
**Corner scale:** xs 6 · sm 12 · md 16 · lg 20 · xl 28 · xxl 32 · full.

**Shape family** (`PulseShape`, SVGs in `assets/shapes/`). Scalloped shapes use r(θ) = R + A·cos(nθ).

| Shape | Where |
|---|---|
| cookie12 | Hero metric (ping), network hero decoration, uptime, logo |
| cookie9 | Ping tool badge, open ports, destination marker, small live spinners |
| clover4 | Packet-loss badge, filtered ports, ping/jitter stat (speed), devices-found count |
| sunny | Speed-test badge, jitter stat |
| burst | Packet-loss hero |
| flower | "No incidents" empty state, accent picker |
| arch | Traceroute badge, Cloudflare host badge, upload-pending tile |
| square (30% radius) | Port-scan badge, time stat |
| pill | LAN-scan badge |
| circle | Geo IP badge, Router host badge |
| diamond | Monitor badge, "biggest jump" marker |

**Segmented list** (M3 Expressive grouped list): items are separate containers with a 3 px gap. Corners are 24 on the outside of the group and 6 between items. A selected item becomes fully rounded (24) and switches to `secondaryContainer`. Helper: `segmentedRadius(index, count)`.

**Connected button group:** buttons sit 3 px apart with 24 outer and 8 inner corners. The selected button gets flex 1.35, fully rounded corners, and pink fill. Completed steps show a check and use `tertiary` text. Used for test phases (Ping ✓ · Download · Upload), port range, theme, and time range.

**Press morph:** on press, any button or tile scales to 0.94 and tightens its corners toward 14 (`PulsePressable`).

## 5. Layout
**Phone (390 × 844 reference)**
- 40 pt top safe area. App bar 64, or 72 for large-title top-level screens.
- 16 pt side gutters, about 12 pt between sections, 3 pt inside segmented lists.
- Navigation bar 80 pt with 4 tabs. A FAB, when present, sits at right 16 and bottom 96.

**Tablet (1280 × 800 landscape reference)**
- Navigation rail 96 dp. From the top: brand mark (48), "+" button (56, primaryContainer), Ping / Network / Tools / History, then a spacer, then Settings.
- Content padding 24–28.
- List-detail: a 300 dp pane (`surfaceContainer`, radius 28, 12 dp vertical margin) next to the content.
- Tool screens: rail, Tools pane listing all 8 tools with last results, then content.

**Breakpoints:** compact < 600 uses the navigation bar. Medium 600–839 uses the rail with a single pane. Expanded ≥ 840 uses the rail plus list-detail where specified.

## 6. Surfaces and elevation
- Use tonal surfaces for hierarchy (surface → container → high → highest). `surfaceTint` is off.
- Shadows go only on the FAB and floating elements: dark `0 8 24 rgba(0,0,0,.38)`, light `0 8 22 rgba(70,20,45,.18)`.
- Hero cards (the Network SSID card, the Geo IP place card) are pink with a decorative cookie at 28% white in the corner, spinning.

## 7. Iconography
- 24 px grid with a 2.2 px round stroke, from `assets/icons/`. Icons render in `currentColor`. Use 20–22 px in lists and nav, 18 px in buttons.
- Inside a shape badge, the icon is about 50% of the badge size and uses the shape's "on" color.
- No emoji anywhere.

## 8. Components
Sizes are in logical px and match the prototype.

| Component | Spec |
|---|---|
| **Hero metric** | `PulseShapeBox(cookie12, pink, 220)` that spins (28 s) and breathes (1.2 s). Behind it sits a morphing blob in `secondaryContainer`, offset right and down. Inside: a live dot plus host label (14/700), then the number (displayLarge) and its unit (22/800), all `onPrimaryFixed`. Phone 220 px; tablet detail 260 px. |
| **Stat row** | 4 tiles in a row, `surfaceContainerHigh`, 6 px gaps, 20 px outer corners and 6 px inner. Label 12 `onSurfaceVariant`; value `pulseNumber(20)`. |
| **Segmented list item** | min height 56 (58–62 for richer rows). Contents: 40 px lead (shape badge, circle, or arch container with icon), headline 16/600, supporting 13 `onSurfaceVariant`, trailing value `pulseNumber` plus a small unit. |
| **Chip (filter)** | 40 px tall, radius 12, 1 px `outlineVariant` border. Selected: no border, `secondaryContainer`, radius 20, leading check. Small variant is 32 px. |
| **Search / target field** | 56 px stadium in `surfaceContainerHigh`. Leading search icon, value 17/600, trailing auxiliary text (resolved IP, duration) 13 `onSurfaceVariant`. |
| **Connected button group** | See §4. Height 48 (40 for the small variant). |
| **Shape badge** | A shape from §4 in a fixed brand color with an icon inside. 40 px in lists, 44 on phone tool tiles, 72 on tablet tool tiles. |
| **Tool tile** | Phone: 138 px tall, radius 28. Tablet: half of a 4×2 grid. Badge at top left; name 19/800 wdth 110 (28 on tablet) and last result 13 at the bottom. The Monitor tile is pink with a "LIVE" dot when monitoring is on. |
| **Pill bar sparkline** | Bars 6–9 px wide with fully rounded ends and 3–6 px gaps, colored by latency. A lost packet is a small pink dot aligned to the top. The newest bar is on the right. Bars grow from 0 with a 25 ms stagger on entrance. |
| **Wavy linear progress** | 4 px stroke, wavelength 24, amplitude 3, wave travels in 1.1 s. Track is `secondaryContainer`, separated from the wave by an 8–10 px gap, with a 2.5 px stop dot at the end. When complete, the full width is wavy in `tertiary`. |
| **Wavy circular gauge** | Track ring 12 px in `surfaceContainerHigh`. Active arc is a 16-wave ring, 11 px stroke, pink, starting at 12 o'clock, with the wave travelling. Value is shown on a log scale (1–500 Mbps → 0–1). The number sits in the center. Phone 280, tablet 400. |
| **Route rail** | A sine path through 21 nodes (5 px dots colored by latency, timeouts as dashed rings, destination as a spinning cookie9). "+55" callout bubble in `primaryContainer` above the jump. Labels You · Bangladesh · Singapore. |
| **Port map** | Grid of rounded cells: phone 22 × 3 (common ports), tablet 32 × 8 (1–1024, 4 ports per cell). Open is pink, filtered is lavender, closed is an outline only. |
| **Timeline grid** | One cell per packet for the full test duration (300 for 5 min at 1/s). OK is latency-fast, late is latency-medium, lost is latency-slow, future cells are `surfaceContainerHighest`. |
| **Map card** | Radius 28. Sea is `mapSea`, land is `mapLand`, borders are `mapBorder` at 1 px. Route is a quadratic arc, dashed (6/6) in `primary` with a flowing dash, plus a travelling packet dot. "You" marker: lime dot ringed in `onLime`, with an inverse-surface label. Target marker: spinning pink cookie9 with a sonar ring and a pink label. |
| **FAB** | 60 tall, radius 20, pink with `onPink` content, 18 px icon plus label 16/800. |
| **Navigation bar** | 80 tall, `surfaceContainer`. Indicator 56 × 32 stadium in `secondaryContainer`. Labels 12; the active label is 700 weight. |
| **Navigation rail** | See §5. Same indicator style as the navigation bar. |
| **Switch row** | Segmented list item with a trailing M3 switch. On: track `primary`, thumb `onPrimary`. |
| **Theme preview card** | Tablet Settings: a mini UI (cookie and two bars) per theme. System is split light/dark. Selected card uses `secondaryContainer` with a check. |

## 9. Patterns
- **Live values** update about every 1 s (the ping interval) with `PulseLiveValue`: a 250 ms slide and fade. Don't animate every digit separately.
- **Verdict pills:** No loss (lime) · Unstable (lavender) · Degraded / +55 ms (pink) · Timeouts (outline). Pair each with one sentence of explanation when there's room.
- **Run states** for every tool. *Idle:* target field plus primary action. *Running:* wavy progress, live numbers, Stop/Cancel as a tonal or pink button. *Done:* summary and verdict, Run again, Copy/Save/Share. *Error:* `errorContainer` banner with a cause and a retry. Keep the last result visible while a new run starts.
- **Empty states** use a large flower or clover shape in lavender with a check or icon, a 22/700 title, and one helpful sentence (see Monitor → No incidents).
- **List-detail on tablet:** the selected item in the pane is the fully rounded `secondaryContainer` row. The detail pane has no container of its own and sits on `surface`.
- **Privacy explanations:** OS-hidden values (MAC address) show "Hidden by Android" (or "Hidden by iOS") in `onSurfaceVariant` with an info button, never "—" alone.
- **Destructive actions** (clear history, delete a run) are text or outlined buttons with a confirm dialog. They're never pink.

## 10. Motion
Curves: `PulseMotion.spring` = cubic(0.3, 1.4, 0.5, 1); `emphasizedDecelerate` = cubic(0.05, 0.7, 0.1, 1).

| Motion | Where | Trigger | Duration / curve | Flutter |
|---|---|---|---|---|
| Logo heartbeat | Splash, rail brand | Loop | ECG draws on (40%), holds (35%), draws off (25%); mark pumps 1 → 1.06 → .98 → 1.02 → 1; 2.4 s | `PulseLogo` |
| Logo spin | Logo cookie | Loop | 24 s linear | `PulseLogo` |
| Hero spin + breathe | Hero cookie | Loop | Spin 28 s linear; scale 1 → 1.035, 1.2 s ease-in-out, reversing | `PulseShapeBox(spin:, breathe:)` |
| Blob morph | Behind hero | Loop | 9 s ease-in-out, border-radius morph plus 30° rotate | `AnimatedContainer` / custom painter |
| Small spins | Badges, markers, uptime, accent | Loop | 10 s (cookie9), 22–28 s (large) | `PulseShapeBox(spin:)` |
| Wobble | Clover tiles | Loop | ±8°, 4 s | `RotationTransition` |
| Entrance | Cards, list rows, tiles | Screen open | 600 ms, emphasizedDecelerate, 16 px rise and scale .97 → 1, 40 ms stagger (tablet panes: 10 px from the left) | `PulseEntrance(index:)` |
| Shape pop | Stat shapes, hero shapes | Screen open | 700 ms spring from scale .6 / −24° | `ScaleTransition` + `RotationTransition` |
| Chip pop | Chips | Screen open | 450 ms spring from scale .8 | |
| Bar grow | Sparklines, signal bars | Screen open / new sample | 600 ms spring from scaleY 0, 25 ms stagger | `TweenAnimationBuilder` |
| Cell pop | Port map, timeline | Result arrives | 300 ms spring from scale .3, 4–8 ms stagger | |
| Node pop | Route rail | Hop resolves | 450 ms spring 0 → 1.3 → 1 | |
| Path draw | Route rail, gauge arc | Data arrives | 1.6 s emphasizedDecelerate | `PathMetric.extractPath` |
| Wave travel | Wavy progress | While running | 1.1 s per wavelength, linear | `WavyProgress` |
| Gauge value | Speed gauge | New sample | 900 ms emphasizedDecelerate between values | `WavyProgress(circular: true)` |
| Packet travel | Map route | Loop | 2.6 s ease-in-out along the arc, fading at the ends | `PathMetric.getTangentForOffset` |
| Sonar | Target marker | Loop | 2 s, scale 1 → 2.6, fades out | |
| Live dot | Live labels | Loop | 1.4 s opacity 1 ↔ .3 | `PulseLiveDot` |
| Live value | Every live number | Every sample | 250 ms slide (25%) and fade | `PulseLiveValue` |
| Press | Buttons, tiles, list items | Pointer down | 200 ms spring scale .94, corners toward 14 | `PulsePressable` |
| Selection morph | Button group, chips, nav | Select | 350 ms spring: flex 1 → 1.35, radius 8 → 24 | `AnimatedContainer` / `AnimatedFlex` |
| Page transition | Push / pop | Navigation | Predictive back on Android, Cupertino on iOS | theme `pageTransitionsTheme` |

**Reduce motion:** when `MediaQuery.disableAnimations` is true, or the app's "Expressive motion" switch is off, stop every loop at its rest pose. Entrances become instant and live values change without a transition. The helpers in `tokens/` already handle the system setting. For the app switch, wrap the app in `MediaQuery(data: mq.copyWith(disableAnimations: true))` when it's off.

## 11. Accessibility
- Text contrast is ≥ 4.5:1 for all pairs in this system, including `onSurfaceVariant` on containers. Never put white text on pink, lime or lavender; use the "on" pair.
- Latency is never shown by color alone: the value is always printed, and timeouts use a dashed ring plus the text "No reply".
- Touch targets are ≥ 48 dp. Icon-only buttons need tooltips and semantic labels.
- Charts need a `Semantics` summary (e.g. "Last 60 pings, average 39 ms, max 89").
- Large text: titles may wrap to 2 lines. Hero numbers scale with `MediaQuery.textScaler`, clamped at 1.3.

## 12. Do / don't
- **Do** keep one hero shape per screen and let everything else be tonal containers.
- **Do** use fixed brand colors for shapes and theme roles for chrome.
- **Don't** add gradients, glassmorphism, or colored left borders on cards.
- **Don't** use pink for errors. Pink means attention or brand; real errors use the error roles.
- **Don't** spin text. Rotate only the shape behind it.
