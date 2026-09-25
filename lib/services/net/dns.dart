import 'dart:async';
import 'dart:io';

import 'ping_prober.dart';

/// Thrown when a host name does not resolve.
class DnsFailure implements Exception {
  DnsFailure(this.host, [this.reason]);
  final String host;
  final String? reason;

  @override
  String toString() => 'DNS lookup failed for $host${reason == null ? '' : ' ($reason)'}';
}

class Dns {
  Dns._();

  static bool isIp(String s) => InternetAddress.tryParse(s) != null;

  /// Resolves [host] for [family]. IP literals are returned as-is.
  static Future<InternetAddress> resolve(
    String host, {
    ProbeFamily family = ProbeFamily.auto,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final literal = InternetAddress.tryParse(host);
    if (literal != null) return literal;
    final type = switch (family) {
      ProbeFamily.ipv4 => InternetAddressType.IPv4,
      ProbeFamily.ipv6 => InternetAddressType.IPv6,
      ProbeFamily.auto => InternetAddressType.any,
    };
    try {
      final all = await InternetAddress.lookup(host, type: type).timeout(timeout);
      if (all.isEmpty) throw DnsFailure(host, 'no records');
      if (family == ProbeFamily.auto) {
        return all.firstWhere(
          (a) => a.type == InternetAddressType.IPv4,
          orElse: () => all.first,
        );
      }
      return all.first;
    } on SocketException catch (e) {
      throw DnsFailure(host, e.osError?.message ?? e.message);
    } on TimeoutException {
      throw DnsFailure(host, 'timed out');
    }
  }

  /// All addresses for [host] (both families).
  static Future<List<InternetAddress>> resolveAll(String host) async {
    final literal = InternetAddress.tryParse(host);
    if (literal != null) return [literal];
    try {
      return await InternetAddress.lookup(host).timeout(const Duration(seconds: 5));
    } on Object {
      return const [];
    }
  }

  /// Reverse DNS (PTR) for an IP, or null.
  static Future<String?> reverse(String ip) async {
    final addr = InternetAddress.tryParse(ip);
    if (addr == null) return null;
    try {
      final r = await addr.reverse().timeout(const Duration(seconds: 3));
      return r.host == ip ? null : r.host;
    } on Object {
      return null;
    }
  }

  /// A one-line companion for a target: its PTR name for IPs, its first
  /// address for names.
  static Future<String?> describe(String host) async {
    if (isIp(host)) return reverse(host);
    try {
      return (await resolve(host)).address;
    } on DnsFailure {
      return null;
    }
  }
}
