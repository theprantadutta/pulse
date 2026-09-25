@Tags(['render'])
library;

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/widgets/wire/wire.dart';
import 'package:pulse/presentations/screens/loss/loss_screen.dart';
import 'package:pulse/providers/loss_provider.dart';

import 'render_harness.dart';

LossRun _run() {
  final r = Random(5);
  const total = 300;
  final packets = <PacketState>[];
  final rtts = <double?>[];
  for (var i = 0; i < total; i++) {
    if (i >= 192) {
      packets.add(PacketState.pending);
      rtts.add(null);
      continue;
    }
    final burst = i % 40 > 36;
    final x = r.nextDouble();
    final s = burst && x > 0.3 ? PacketState.lost : x > 0.94 ? PacketState.late : PacketState.ok;
    packets.add(s);
    rtts.add(s == PacketState.lost ? null : s == PacketState.late ? 180 : 70 + x * 30);
  }
  return LossRun(packets: packets, rtts: rtts);
}

class _Fake extends LossNotifier {
  @override
  LossState build() => LossState(
    target: 'discord.gg',
    address: '162.159.135.232',
    run: _run(),
    running: true,
    startedAt: DateTime.now().subtract(const Duration(minutes: 3, seconds: 12)),
  );
}

void main() {
  setUpAll(loadWireFonts);
  test('verdict detects periodic bursts', () {
    final v = lossVerdict(LossState(target: 'x', run: _run()));
    expect(v.text, contains('bursts every ~40 s'));
  });
  Widget app(Brightness b) => ProviderScope(
    overrides: [lossProvider.overrideWith(_Fake.new)],
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildWireTheme(b), home: const Scaffold(body: LossScreen())),
  );
  testWidgets('loss screens', (tester) async {
    await renderToPng(tester, 'loss_desktop_light', app(Brightness.light), size: const Size(1060, 736));
    await renderToPng(tester, 'loss_mobile_dark', app(Brightness.dark), size: const Size(390, 780));
  });
}
