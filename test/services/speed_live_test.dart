@Tags(['network'])
library;

import 'package:pulse/services/net/speed_test.dart';
import 'package:test/test.dart';

void main() {
  test('gauge scale', () {
    expect(gaugeFraction(50), 0.25);
    expect(gaugeFraction(175), closeTo(0.625, 0.001));
    expect(gaugeFraction(900), 1);
  });

  test('real speed test against Cloudflare (short)', () async {
    final t = SpeedTest(downloadTime: const Duration(seconds: 4), uploadTime: const Duration(seconds: 3), streams: 3);
    SpeedUpdate? last;
    await for (final u in t.run(kSpeedServers.first)) {
      last = u;
    }
    // ignore: avoid_print
    print(
      'colo=${last!.colo} ping=${last.pingMs?.toStringAsFixed(1)} jitter=${last.jitterMs?.toStringAsFixed(1)} '
      'down=${last.downMbps?.toStringAsFixed(1)} up=${last.upMbps?.toStringAsFixed(1)}',
    );
    expect(last.phase, SpeedPhase.done);
    expect(last.downMbps, greaterThan(0));
    expect(last.upMbps, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('auto select', () async {
    final (s, ms) = await SpeedTest().autoSelect();
    // ignore: avoid_print
    print('auto: ${s.name} ${s.location} ${ms?.toStringAsFixed(1)} ms');
  }, timeout: const Timeout(Duration(minutes: 1)));
}
