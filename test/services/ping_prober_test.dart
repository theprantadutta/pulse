import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/services/net/ping_prober.dart';

void main() {
  group('parsePingOutput', () {
    test('Windows reply', () {
      final r = parsePingOutput('''
Pinging 8.8.8.8 with 56 bytes of data:
Reply from 8.8.8.8: bytes=56 time=79ms TTL=116

Ping statistics for 8.8.8.8:
    Packets: Sent = 1, Received = 1, Lost = 0 (0% loss),''');
      expect(r.status, ProbeStatus.ok);
      expect(r.rttMs, 79);
      expect(r.ttl, 116);
      expect(r.from, '8.8.8.8');
    });

    test('Windows sub-millisecond reply', () {
      final r = parsePingOutput('Reply from 192.168.1.1: bytes=32 time<1ms TTL=64');
      expect(r.status, ProbeStatus.ok);
      expect(r.rttMs, 0.5);
    });

    test('Windows TTL expired', () {
      final r = parsePingOutput('Reply from 50.50.50.1: TTL expired in transit.');
      expect(r.status, ProbeStatus.ttlExceeded);
      expect(r.from, '50.50.50.1');
    });

    test('Windows timeout and unknown host', () {
      expect(parsePingOutput('Request timed out.').status, ProbeStatus.timeout);
      expect(
        parsePingOutput('Ping request could not find host nosuch.invalid. Please check the name and try again.').status,
        ProbeStatus.unknownHost,
      );
    });

    test('Windows destination unreachable', () {
      final r = parsePingOutput('Reply from 192.168.1.42: Destination host unreachable.');
      expect(r.status, ProbeStatus.unreachable);
    });

    test('Linux iputils reply', () {
      final r = parsePingOutput('''
PING dns.google (8.8.8.8) 56(84) bytes of data.
64 bytes from dns.google (8.8.8.8): icmp_seq=1 ttl=117 time=24.6 ms

--- dns.google ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms''');
      expect(r.status, ProbeStatus.ok);
      expect(r.rttMs, 24.6);
      expect(r.ttl, 117);
      expect(r.from, '8.8.8.8');
    });

    test('Linux TTL exceeded', () {
      final r = parsePingOutput('From 192.168.1.1 icmp_seq=1 Time to live exceeded');
      expect(r.status, ProbeStatus.ttlExceeded);
      expect(r.from, '192.168.1.1');
    });

    test('macOS reply and TTL exceeded', () {
      final ok = parsePingOutput('64 bytes from 1.1.1.1: icmp_seq=0 ttl=57 time=18.214 ms');
      expect(ok.rttMs, closeTo(18.214, 0.001));
      final hop = parsePingOutput('92 bytes from 10.0.0.1: Time to live exceeded');
      expect(hop.status, ProbeStatus.ttlExceeded);
      expect(hop.from, '10.0.0.1');
    });

    test('Android toybox reply and bad address', () {
      final ok = parsePingOutput('64 bytes from 142.250.183.14: icmp_seq=1 ttl=115 time=31.2 ms');
      expect(ok.status, ProbeStatus.ok);
      expect(parsePingOutput('ping: nosuch.invalid: bad address').status, ProbeStatus.unknownHost);
    });

    test('IPv6 reply', () {
      final r = parsePingOutput(
        '64 bytes from 2606:4700:4700::1111: icmp_seq=1 ttl=58 time=12.1 ms',
      );
      expect(r.status, ProbeStatus.ok);
      expect(r.from, '2606:4700:4700::1111');
    });
  });
}
