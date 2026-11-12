@Tags(['render'])
library;

import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/presentations/screens/loss/loss_screen.dart';
import 'package:pulse/providers/database_provider.dart';
import 'package:pulse/providers/loss_provider.dart';
import 'package:pulse/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_harness.dart';

/// Periodic bursts every 40 packets (degraded, "bursts every ~40 s").
LossRun _burstyRun() {
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
    final s = burst && x > 0.3
        ? PacketState.lost
        : x > 0.94
        ? PacketState.late
        : PacketState.ok;
    packets.add(s);
    rtts.add(
      s == PacketState.lost
          ? null
          : s == PacketState.late
          ? 180
          : 70 + x * 30,
    );
  }
  return LossRun(packets: packets, rtts: rtts);
}

/// Kit sample: 89 of 300 sent to 1.1.1.1, packets 6 and 52 lost.
LossRun _kitRun({int sent = 89, List<int> lost = const [5, 51]}) {
  const total = 300;
  return LossRun(
    packets: [
      for (var i = 0; i < total; i++)
        i >= sent
            ? PacketState.pending
            : lost.contains(i)
            ? PacketState.lost
            : PacketState.ok,
    ],
    rtts: [
      for (var i = 0; i < total; i++)
        i >= sent || lost.contains(i) ? null : 11 + (sin(i * 1.7)).abs() * 5 + (i % 23 == 7 ? 18 : 0),
    ],
  );
}

class _Fake extends LossNotifier {
  _Fake(this.initial);
  final LossState initial;

  @override
  LossState build() => initial;
}

void main() {
  setUpAll(loadPulseFonts);

  group('verdict', () {
    test('periodic bursts are degraded and explained', () {
      final v = lossVerdict(LossState(target: 'x', run: _burstyRun()));
      expect(v.word, 'degraded');
      expect(v.text, contains('bursts every ~40 s'));
    });
    test('isolated drops are unstable', () {
      final v = lossVerdict(LossState(target: '1.1.1.1', run: _kitRun()));
      expect(v.word, 'unstable');
      expect(v.text, startsWith('Drops are isolated single packets'));
    });
    test('no loss is stable', () {
      expect(
        lossVerdict(
          LossState(
            target: 'x',
            run: _kitRun(lost: []),
          ),
        ).word,
        'stable',
      );
    });
    test('a single drop in 200 is mostly stable', () {
      expect(
        lossVerdict(
          LossState(
            target: 'x',
            run: _kitRun(sent: 200, lost: [40]),
          ),
        ).word,
        'mostly stable',
      );
    });
    test('comparison avoids pinging the target itself', () {
      expect(const LossState(target: '1.1.1.1').compareHost, '8.8.8.8');
      expect(const LossState(target: 'discord.gg').compareHost, '1.1.1.1');
    });
  });

  Future<ProviderContainer> seed(LossState state) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
        lossProvider.overrideWith(() => _Fake(state)),
      ],
    );
  }

  Future<List<String>> render(
    WidgetTester tester,
    String name,
    LossState state, {
    bool phoneOnly = false,
    String? target,
  }) async {
    final c = (await tester.runAsync(() => seed(state)))!;
    final failures = await renderMatrix(
      tester,
      name,
      c,
      LossScreen(initialTarget: target),
      location: '/loss',
      devices: phoneOnly ? const {'phone': kPhone} : const {'phone': kPhone, 'tablet': kTablet},
    );
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    return failures;
  }

  testWidgets('loss running', (tester) async {
    final state = LossState(
      target: '1.1.1.1',
      address: '1.1.1.1',
      run: _kitRun(),
      running: true,
      startedAt: DateTime.now().subtract(const Duration(minutes: 1, seconds: 29)),
    );
    expect(await render(tester, 'loss', state), isEmpty);
  });

  testWidgets('loss idle', (tester) async {
    expect(await render(tester, 'loss_idle', const LossState(), target: '1.1.1.1'), isEmpty);
  });

  testWidgets('loss done (bursty, compared)', (tester) async {
    final state = LossState(
      target: 'discord.gg',
      address: '162.159.135.232',
      run: _burstyRun(),
      compare: _kitRun(sent: 150, lost: []),
      startedAt: DateTime.now().subtract(const Duration(minutes: 4)),
    );
    expect(await render(tester, 'loss_done', state), isEmpty);
  });

  testWidgets('loss error', (tester) async {
    expect(
      await render(
        tester,
        'loss_error',
        const LossState(target: 'nope.invalid', error: 'DNS lookup failed for nope.invalid'),
        target: 'nope.invalid',
        phoneOnly: true,
      ),
      isEmpty,
    );
  });
}
