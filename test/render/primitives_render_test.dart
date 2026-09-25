@Tags(['render'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/brand/pulse_mark.dart';
import 'package:pulse/core/widgets/wire/wire.dart';

import 'render_harness.dart';

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(color: w.signal, padding: const EdgeInsets.all(12), child: const PulseLockup(height: 34)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const WireButton(
                        label: 'Start',
                        glyph: '▶',
                        variant: WireButtonVariant.primary,
                        onPressed: _noop,
                      ),
                      const WireButton(label: 'Stop', glyph: '■', variant: WireButtonVariant.inverse, onPressed: _noop),
                      const WireButton(label: 'Copy', onPressed: _noop),
                      const SizedBox(width: 12),
                      WireToggle(value: true, onChanged: (_) {}),
                      WireToggle(value: false, onChanged: (_) {}),
                    ],
                  ),
                  const SizedBox(height: 12),
                  WireSegmented<int>(
                    options: const [(4, '4'), (10, '10'), (50, '50'), (0, '∞')],
                    selected: 0,
                    onChanged: (_) {},
                  ),
                  const SizedBox(height: 12),
                  const WireHeroNumber(value: '25', unit: 'ms', size: 190),
                  const WireBox(
                    child: WireSplitRow(
                      children: [
                        WireStat(label: 'Sent', value: '30'),
                        WireStat(label: 'Loss', value: '0%'),
                        WireStat(label: 'Uptime', value: '99.7%', tone: WireTone.signal),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 150,
                    child: WireBox(
                      child: WireBarChart.latency(
                        values: const [22, 24, 27, 30, 26, 25, 45, 26, 112, 24, null, 23, 29, 21, 25, 27],
                        threshold: 60,
                        slots: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  WireStatusStrip(
                    colors: [
                      for (var i = 0; i < 48; i++)
                        i == 20
                            ? w.signal
                            : i == 12
                            ? w.degraded
                            : w.ink,
                    ],
                  ),
                  const SizedBox(height: 12),
                  const WireProgress(value: 0.72),
                  const SizedBox(height: 12),
                  const WireSectionBar('Recent targets'),
                  const WireRow(child: Text('1.1.1.1')),
                  const WireRow(highlight: WireRowHighlight.tint, child: Text('017  112ms  SLOW')),
                  const WireRow(highlight: WireRowHighlight.muted, child: Text('* * *  TIMEOUT')),
                  const WireKeyValueRow(label: 'Local IPv4', value: '192.168.1.42'),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      WireTag('Gateway'),
                      SizedBox(width: 8),
                      WireTag('New', tone: WireTone.signal),
                      SizedBox(width: 8),
                      WireBlockMeter(filled: 3),
                      SizedBox(width: 8),
                      PulseMark(size: 48, colorway: PulseMarkColorway.paper),
                      PulseMark(size: 48, contained: true),
                      PulseMark(size: 48, contained: true, colorway: PulseMarkColorway.dark),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const WireErrorBlock(reason: 'DNS lookup failed for nosuch.host', size: 64),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _noop() {}

void main() {
  setUpAll(loadWireFonts);

  for (final b in Brightness.values) {
    testWidgets('primitives gallery ${b.name}', (tester) async {
      await renderToPng(
        tester,
        'primitives_${b.name}',
        MaterialApp(debugShowCheckedModeBanner: false, theme: buildWireTheme(b), home: const _Gallery()),
      );
    });
  }
}
