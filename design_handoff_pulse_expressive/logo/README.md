# Logo A: "Heartbeat Cookie"

A pink 12-scallop cookie (`#FFAFD0`) with a heartbeat line (`#4A0F2C`). The app-icon tile is berry `#4A1D3B`.
Geometry (120-unit box): cookie r(θ) = 42 + 4.5·cos(12θ) around (60,60). The heartbeat polyline is `M26 62 H43 L50 46 L60 80 L69 38 L76 62 H94`, stroke 7, round caps and joins.

| File | Use |
|---|---|
| `svg/pulse-mark.svg` | Mark on any background (≥ 48 px) |
| `svg/pulse-mark-simple.svg` | Small sizes (≤ 32 px): circle instead of scallops, thicker line |
| `svg/pulse-mark-mono.svg` | Single color (`currentColor`), heartbeat cut out. Themed icons, notifications |
| `svg/pulse-mark-animated.svg` | Animated reference (CSS). Flutter: `PulseLogo` in `tokens/pulse_shapes.dart` |
| `svg/pulse-app-icon*.svg` | Rounded / circle / square app-icon tiles |
| `svg/android-adaptive-*.svg` | Adaptive icon layers (108 dp canvas, art inside the 66 dp safe zone) |
| `svg/android12-splash-icon.svg` | Android 12+ splash icon (288 dp canvas) |
| `svg/pulse-lockup-on-{dark,light}.svg` | Icon + wordmark, horizontal |
| `svg/pulse-stacked-{dark,light}.svg` | Stacked logo on a theme background |
| `svg/pulse-wordmark.svg` | "Pulse" outlined from Roboto Flex 800 / wdth 125 (`currentColor`) |
| `png/ios/` | Opaque square AppIcon PNGs, 20–1024 |
| `png/android/` | Play Store 512, adaptive foreground/background/monochrome 432 px, legacy mipmaps, Android 12 splash 1152 px |
| `png/brand/` | Mark, lockups, stacked, wordmark PNGs |

Clear space is at least 25% of the mark's width on every side. Don't recolor the cookie (except mono), rotate the heartbeat, add effects, or set the wordmark in another font.
