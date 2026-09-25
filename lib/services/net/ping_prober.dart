import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_ping/dart_ping.dart';

import 'dns.dart';
import 'windows_icmp.dart';

/// IP family for a single probe.
enum ProbeFamily { auto, ipv4, ipv6 }

enum ProbeStatus {
  /// Echo reply received.
  ok,

  /// No reply within the timeout.
  timeout,

  /// A router answered "time to live exceeded" (traceroute hop).
  ttlExceeded,

  /// Destination/network unreachable.
  unreachable,

  /// The name did not resolve.
  unknownHost,

  /// The probe could not be sent at all.
  error,
}

class ProbeResult {
  const ProbeResult({required this.status, this.rttMs, this.ttl, this.from, this.message});

  final ProbeStatus status;

  /// Round-trip time in milliseconds (also set for TTL-exceeded replies).
  final double? rttMs;

  /// TTL of the echo reply.
  final int? ttl;

  /// Address that answered (the host, or the router for TTL exceeded).
  final String? from;
  final String? message;

  bool get ok => status == ProbeStatus.ok;

  @override
  String toString() => 'ProbeResult($status, $rttMs ms, ttl=$ttl, from=$from)';
}

/// Sends exactly one ICMP echo and reports what came back.
///
/// Desktop and Android run the system `ping` (so packet size, TTL, timeout and
/// family are honoured and no raw-socket privileges are needed); iOS uses
/// dart_ping's bundled native ICMP engine.
class PingProber {
  const PingProber();

  /// Payload size in bytes. Not adjustable on iOS, where the native engine
  /// always sends its default payload.
  static bool get supportsPacketSize => !Platform.isIOS;

  Future<ProbeResult> probe(
    String host, {
    Duration timeout = const Duration(seconds: 2),
    int packetSize = 56,
    int ttl = 64,
    ProbeFamily family = ProbeFamily.auto,
  }) async {
    if (!_hostPattern.hasMatch(host)) {
      return const ProbeResult(status: ProbeStatus.error, message: 'Invalid host name');
    }
    if (Platform.isIOS) return _probeIos(host, timeout, ttl, family);
    if (Platform.isWindows && family != ProbeFamily.ipv6) {
      final InternetAddress address;
      try {
        address = await Dns.resolve(host, family: ProbeFamily.ipv4);
      } on DnsFailure {
        if (family == ProbeFamily.auto) {
          return _probeProcess(host, timeout, packetSize, ttl, family);
        }
        return const ProbeResult(status: ProbeStatus.unknownHost, message: 'DNS lookup failed');
      }
      return WindowsIcmp.echo(address, timeout: timeout, packetSize: packetSize, ttl: ttl);
    }
    return _probeProcess(host, timeout, packetSize, ttl, family);
  }

  static final _hostPattern = RegExp(r'^[A-Za-z0-9.\-:%_\[\]]+$');

  Future<ProbeResult> _probeIos(String host, Duration timeout, int ttl, ProbeFamily family) async {
    final ping = Ping(
      host,
      count: 1,
      timeout: (timeout.inMilliseconds / 1000).ceil().clamp(1, 60),
      ttl: ttl,
      ipVersion: family == ProbeFamily.ipv6 ? IpVersion.ipv6 : IpVersion.ipv4,
    );
    try {
      await for (final event in ping.stream.timeout(timeout + const Duration(seconds: 2))) {
        switch (event) {
          case PingResponse(:final time, :final ttl, :final ip):
            if (time == null) {
              return const ProbeResult(status: ProbeStatus.timeout);
            }
            return ProbeResult(status: ProbeStatus.ok, rttMs: time.inMicroseconds / 1000, ttl: ttl, from: ip);
          case PingError(:final error, :final ip, :final message):
            return switch (error) {
              ErrorType.timeToLiveExceeded => ProbeResult(status: ProbeStatus.ttlExceeded, from: ip),
              ErrorType.unknownHost => const ProbeResult(status: ProbeStatus.unknownHost, message: 'DNS lookup failed'),
              ErrorType.noRoute => ProbeResult(status: ProbeStatus.unreachable, from: ip, message: 'No route to host'),
              ErrorType.requestTimedOut || ErrorType.noReply => const ProbeResult(status: ProbeStatus.timeout),
              ErrorType.unknown => ProbeResult(status: ProbeStatus.error, message: message ?? error.message),
            };
          case PingSummary():
            return const ProbeResult(status: ProbeStatus.timeout);
        }
      }
    } on TimeoutException {
      await ping.stop();
      return const ProbeResult(status: ProbeStatus.timeout);
    } catch (e) {
      return ProbeResult(status: ProbeStatus.error, message: '$e');
    }
    return const ProbeResult(status: ProbeStatus.timeout);
  }

  Future<ProbeResult> _probeProcess(String host, Duration timeout, int packetSize, int ttl, ProbeFamily family) async {
    final (exe, args) = _command(host, timeout, packetSize, ttl, family);
    ProcessResult result;
    try {
      result = await Process.run(
        exe,
        args,
        stdoutEncoding: Platform.isWindows ? const SystemEncoding() : utf8,
        stderrEncoding: Platform.isWindows ? const SystemEncoding() : utf8,
      ).timeout(timeout + const Duration(seconds: 3));
    } on TimeoutException {
      return const ProbeResult(status: ProbeStatus.timeout);
    } on ProcessException catch (e) {
      return ProbeResult(status: ProbeStatus.error, message: e.message);
    }
    return parsePingOutput('${result.stdout}\n${result.stderr}');
  }

  (String, List<String>) _command(String host, Duration timeout, int size, int ttl, ProbeFamily family) {
    final secs = (timeout.inMilliseconds / 1000).ceil().clamp(1, 60);
    if (Platform.isWindows) {
      return (
        'ping',
        [
          '-n',
          '1',
          '-w',
          '${timeout.inMilliseconds}',
          '-l',
          '$size',
          '-i',
          '$ttl',
          if (family == ProbeFamily.ipv4) '-4',
          if (family == ProbeFamily.ipv6) '-6',
          host,
        ],
      );
    }
    if (Platform.isMacOS) {
      if (family == ProbeFamily.ipv6 || (family == ProbeFamily.auto && host.contains(':'))) {
        return ('ping6', ['-c', '1', '-s', '$size', '-h', '$ttl', host]);
      }
      return ('ping', ['-c', '1', '-W', '${timeout.inMilliseconds}', '-s', '$size', '-m', '$ttl', host]);
    }
    if (Platform.isAndroid) {
      // Toybox and legacy AOSP ping both accept these flags; IPv6 goes
      // through the separate ping6 binary instead of a family flag.
      final v6 = family == ProbeFamily.ipv6 || (family == ProbeFamily.auto && host.contains(':'));
      return (
        v6 ? '/system/bin/ping6' : '/system/bin/ping',
        ['-c', '1', '-W', '$secs', '-s', '$size', '-t', '$ttl', host],
      );
    }
    // Linux (iputils).
    return (
      'ping',
      [
        '-c',
        '1',
        '-W',
        '$secs',
        '-s',
        '$size',
        '-t',
        '$ttl',
        if (family == ProbeFamily.ipv4) '-4',
        if (family == ProbeFamily.ipv6) '-6',
        host,
      ],
    );
  }
}

final _ipPattern = RegExp(r'((?:\d{1,3}\.){3}\d{1,3}|[0-9a-fA-F]{0,4}(?::[0-9a-fA-F]{0,4}){2,7}(?:%\w+)?)');
final _timePattern = RegExp(r'[=<]\s?(\d+(?:[.,]\d+)?)\s?ms', caseSensitive: false);
final _ttlPattern = RegExp(r'\b(?:ttl|hlim)[=:]\s?(\d+)', caseSensitive: false);

String? _addr(RegExpMatch? m) {
  final v = m?.group(1);
  if (v == null) return null;
  return v.endsWith(':') && !v.endsWith('::') ? v.substring(0, v.length - 1) : v;
}

/// Parses one-probe output of Windows, macOS, Linux (iputils) and Android
/// (toybox / AOSP) `ping`. Exposed for tests.
ProbeResult parsePingOutput(String output) {
  final lines = const LineSplitter().convert(output);
  final lower = output.toLowerCase();

  if (lower.contains('could not find host') ||
      lower.contains('unknown host') ||
      lower.contains('cannot resolve') ||
      lower.contains('name or service not known') ||
      lower.contains('temporary failure in name resolution') ||
      lower.contains('bad address') ||
      lower.contains('no address associated')) {
    return const ProbeResult(status: ProbeStatus.unknownHost, message: 'DNS lookup failed');
  }

  for (final raw in lines) {
    final line = raw.trim();
    final l = line.toLowerCase();
    if (l.isEmpty) continue;

    final ttlExceeded =
        l.contains('ttl expired') ||
        l.contains('time to live exceeded') ||
        l.contains('time exceeded') ||
        l.contains('hop limit');
    if (ttlExceeded) {
      final from = _ipPattern.firstMatch(line.replaceFirst(RegExp(r'^\d+ bytes '), ''));
      return ProbeResult(status: ProbeStatus.ttlExceeded, from: _addr(from));
    }

    if (l.contains('unreachable') && !l.contains('0% packet loss')) {
      final from = _ipPattern.firstMatch(line);
      return ProbeResult(status: ProbeStatus.unreachable, from: _addr(from), message: 'Destination unreachable');
    }

    final time = _timePattern.firstMatch(line);
    final isReply =
        time != null &&
        (l.contains('ttl') || l.contains('hlim') || l.contains('bytes from') || l.contains('reply from'));
    if (isReply) {
      final ttl = _ttlPattern.firstMatch(line);
      final from = _ipPattern.firstMatch(line.replaceFirst(RegExp(r'^\d+ bytes', caseSensitive: false), ''));
      final ms = double.parse(time.group(1)!.replaceAll(',', '.'));
      // Windows prints "time<1ms" for sub-millisecond replies.
      final rtt = line.contains('<1') ? 0.5 : ms;
      return ProbeResult(
        status: ProbeStatus.ok,
        rttMs: rtt,
        ttl: ttl == null ? null : int.parse(ttl.group(1)!),
        from: _addr(from),
      );
    }
  }

  if (lower.contains('general failure') || lower.contains('transmit failed')) {
    return const ProbeResult(status: ProbeStatus.unreachable, message: 'Transmit failed');
  }
  if (lower.contains('network is unreachable') || lower.contains('no route to host')) {
    return const ProbeResult(status: ProbeStatus.unreachable, message: 'Network is unreachable');
  }
  return const ProbeResult(status: ProbeStatus.timeout);
}
