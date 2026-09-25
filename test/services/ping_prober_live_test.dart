@Tags(['network'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/services/net/ping_prober.dart';

void main() {
  group('live probe', () {
    const prober = PingProber();

    test('loopback answers', () async {
      final r = await prober.probe('127.0.0.1', timeout: const Duration(seconds: 2));
      expect(r.status, ProbeStatus.ok);
      expect(r.rttMs, isNotNull);
    });

    test('TTL 1 to a public host expires at the first hop', () async {
      final r = await prober.probe('8.8.8.8', ttl: 1, timeout: const Duration(seconds: 2));
      expect(r.status, anyOf(ProbeStatus.ttlExceeded, ProbeStatus.timeout));
      if (Platform.isWindows && r.status == ProbeStatus.ttlExceeded) {
        expect(r.rttMs, isNotNull);
      }
    });

    test('packet size is honoured', () async {
      final r = await prober.probe('127.0.0.1', packetSize: 1472);
      expect(r.status, ProbeStatus.ok);
    });

    test('unknown host', () async {
      final r = await prober.probe('nosuch.invalid');
      expect(r.status, ProbeStatus.unknownHost);
    });
  });
}
