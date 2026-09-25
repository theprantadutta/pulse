@Tags(['network'])
library;

import 'package:pulse/services/net/traceroute.dart';
import 'package:test/test.dart';

void main() {
  test('real traceroute to 1.1.1.1', () async {
    final sw = Stopwatch()..start();
    TraceResult? last;
    await for (final r in Traceroute().run('1.1.1.1', maxHops: 20, timeout: const Duration(seconds: 1))) {
      last = r;
    }
    // ignore: avoid_print
    print('${sw.elapsed.inMilliseconds} ms reached=${last!.reached}');
    for (final h in last.hops) {
      // ignore: avoid_print
      print(
        '  ${h.n.toString().padLeft(2)} ${(h.ip ?? '*').padRight(16)} ${(h.host ?? '').padRight(40)} '
        '${h.probes.map((p) => p?.toStringAsFixed(0) ?? '*').join(' / ').padRight(14)} ${h.countryCode ?? ''} ${h.city ?? ''}',
      );
    }
    final jump = biggestJump(last.hops);
    // ignore: avoid_print
    print('jump: $jump');
    expect(last.hops, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
