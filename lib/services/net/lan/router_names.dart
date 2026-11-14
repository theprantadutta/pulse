import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'dns_wire.dart';

/// Asks the router's own DNS server for the names it handed out with DHCP
/// ("Galaxy-A24", "DESKTOP-4F2K"). Queries go straight to port 53 on the
/// router and other private DNS servers of the network, so a phone's Private
/// DNS (DNS-over-TLS to a public resolver, which can't know LAN names) doesn't
/// swallow them.
class RouterNames {
  RouterNames._();

  /// IP → name for every IP in [ips] that a server knew. [servers] are tried
  /// together; only private IPv4 servers are used.
  static Future<Map<String, String>> lookup(
    List<String> ips, {
    required List<String> servers,
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    final targets = servers.where(isPrivateIpv4).toSet();
    if (ips.isEmpty || targets.isEmpty) return const {};
    RawDatagramSocket? socket;
    final names = <String, String>{};
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final base = Random().nextInt(0xFFFF);
      final byId = <int, String>{};
      for (var i = 0; i < ips.length; i++) {
        byId[(base + i) & 0xFFFF] = ips[i];
      }
      final done = Completer<void>();
      final sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final d = socket!.receive();
        if (d == null || !targets.contains(d.address.address)) return;
        final msg = DnsMessage.parse(d.data);
        final ip = msg == null ? null : byId[msg.id];
        if (msg == null || ip == null || !msg.isResponse) return;
        for (final r in msg.records) {
          final name = clean(r.ptr, ip);
          if (name != null) {
            names[ip] = name;
            break;
          }
        }
        if (names.length == ips.length && !done.isCompleted) done.complete();
      });
      for (final server in targets) {
        final addr = InternetAddress(server);
        byId.forEach((id, ip) {
          socket!.send(
            DnsWire.query(id, [(name: DnsWire.reverseName(ip), type: DnsType.ptr)], recursion: true),
            addr,
            53,
          );
        });
      }
      await done.future.timeout(timeout, onTimeout: () {});
      await sub.cancel();
    } on Object {
      // No route to the router's DNS: keep what we have.
    } finally {
      socket?.close();
    }
    return names;
  }

  /// Drops the router's search domain and names that only repeat the address
  /// ("192-168-0-31.home", "host-31").
  static String? clean(String? name, String ip) {
    if (name == null || name.isEmpty) return null;
    final full = name.replaceAll(RegExp(r'\.$'), '');
    // Some routers answer with the address itself or a number.
    if (RegExp(r'^[\d.]+$').hasMatch(full) || full.endsWith('in-addr.arpa')) return null;
    final first = full.split('.').first;
    final dashed = ip.replaceAll('.', '-');
    final last = ip.split('.').last;
    if (first.isEmpty ||
        first == ip ||
        first.contains(dashed) ||
        RegExp('^(host|ip|dhcp|client)-?$last\$').hasMatch(first)) {
      return null;
    }
    return first;
  }

  static bool isPrivateIpv4(String ip) =>
      ip.startsWith('10.') || ip.startsWith('192.168.') || RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip);
}
