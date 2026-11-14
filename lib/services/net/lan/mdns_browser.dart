import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'dns_wire.dart';

/// What a device announces over mDNS / DNS-SD (Bonjour).
class MdnsInfo {
  MdnsInfo();

  /// Instance names it advertises ("Living Room TV", "Pranta's iPhone").
  final Set<String> instances = {};

  /// Friendly labels of its services ("Google Cast", "AirPlay", "Printer").
  final Set<String> services = {};

  /// Raw service types ("_googlecast._tcp").
  final Set<String> types = {};

  /// Its mDNS host name ("Prantas-MacBook-Pro").
  String? host;

  /// Model from TXT records ("Chromecast", "MacBookPro18,1", "HP LaserJet M110w").
  String? model;

  /// Friendly name from TXT (Google Cast `fn`) — the best name when present.
  String? friendlyName;

  /// MAC address from a workstation record ("[aa:bb:cc:dd:ee:ff]").
  String? mac;

  /// Best name: TXT friendly name, then the most descriptive instance name.
  String? get name {
    if (friendlyName != null) return friendlyName;
    final list = instances.where((n) => n.isNotEmpty && !_machiney(n)).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return list.isEmpty ? null : list.first;
  }

  // "Chromecast-1a2b3c…" style ids aren't names.
  static bool _machiney(String n) => RegExp(r'[0-9a-f]{12,}', caseSensitive: false).hasMatch(n.replaceAll('-', ''));
}

/// Browses DNS-SD services on the local network.
class MdnsBrowser {
  MdnsBrowser._();

  static final _group = InternetAddress('224.0.0.251');

  /// Service types asked for directly (plus whatever devices list under
  /// `_services._dns-sd._udp`), with the label shown in Pulse.
  static const serviceLabels = <String, String>{
    '_googlecast._tcp': 'Google Cast',
    '_airplay._tcp': 'AirPlay',
    '_raop._tcp': 'AirPlay audio',
    '_companion-link._tcp': 'Apple device',
    '_device-info._tcp': 'Device info',
    '_ipp._tcp': 'Printer',
    '_ipps._tcp': 'Printer',
    '_printer._tcp': 'Printer',
    '_pdl-datastream._tcp': 'Printer',
    '_scanner._tcp': 'Scanner',
    '_uscan._tcp': 'Scanner',
    '_hap._tcp': 'HomeKit',
    '_hap._udp': 'HomeKit',
    '_matter._tcp': 'Matter',
    '_matterc._udp': 'Matter',
    '_spotify-connect._tcp': 'Spotify Connect',
    '_sonos._tcp': 'Sonos',
    '_smb._tcp': 'File sharing',
    '_afpovertcp._tcp': 'File sharing',
    '_nfs._tcp': 'File sharing',
    '_ssh._tcp': 'SSH',
    '_sftp-ssh._tcp': 'SSH',
    '_workstation._tcp': 'Computer',
    '_rdp._tcp': 'Remote desktop',
    '_rfb._tcp': 'Screen sharing',
    '_http._tcp': 'Web',
    '_amzn-wplay._tcp': 'Fire TV',
    '_androidtvremote2._tcp': 'Android TV',
    '_nvstream._tcp': 'GameStream',
    '_hue._tcp': 'Philips Hue',
    '_esphomelib._tcp': 'ESPHome',
    '_home-assistant._tcp': 'Home Assistant',
    '_plexmediasvr._tcp': 'Plex',
    '_daap._tcp': 'Music sharing',
    '_mqtt._tcp': 'MQTT',
    '_elg._tcp': 'Elgato',
    '_miio._udp': 'Xiaomi',
  };

  /// IP → what it announced, for every IP accepted by [inSubnet].
  ///
  /// [unicast] hosts are also asked directly on port 5353: many routers and
  /// mesh systems filter multicast between Wi-Fi clients.
  static Future<Map<String, MdnsInfo>> browse({
    required bool Function(String ip) inSubnet,
    List<String> unicast = const [],
    Duration listen = const Duration(milliseconds: 2500),
  }) async {
    final messages = <({String from, DnsMessage msg})>[];
    final asked = <String>{...serviceLabels.keys};
    RawDatagramSocket? socket;
    try {
      // A non-5353 source port makes responders answer us directly
      // (RFC 6762 §6.7), so no multicast lock is needed on Android.
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.multicastHops = 255;
      final id = Random().nextInt(0xFFFF);
      final sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final d = socket!.receive();
        if (d == null || !inSubnet(d.address.address)) return;
        final msg = DnsMessage.parse(d.data);
        if (msg != null && msg.isResponse) messages.add((from: d.address.address, msg: msg));
      });
      void ask(Iterable<String> types) {
        final names = [for (final t in types) '$t.local'];
        // Keep packets well under the 1500-byte MTU.
        for (var i = 0; i < names.length; i += 12) {
          final batch = [for (final n in names.skip(i).take(12)) (name: n, type: DnsType.ptr)];
          final packet = DnsWire.query(id, batch);
          socket!.send(packet, _group, 5353);
          for (final ip in unicast) {
            socket.send(packet, InternetAddress(ip), 5353);
          }
        }
      }

      ask(['_services._dns-sd._udp', ...serviceLabels.keys]);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      // Follow up on types devices listed that we didn't ask about, and repeat
      // once for responders that missed the first packet.
      final listed = <String>{
        for (final m in messages)
          for (final r in m.msg.records)
            if (r.name.startsWith('_services._dns-sd._udp')) ?_serviceType(r.ptr),
      }.difference(asked);
      asked.addAll(listed);
      ask([...serviceLabels.keys, ...listed]);
      await Future<void>.delayed(listen - const Duration(milliseconds: 800));
      await sub.cancel();
    } on Object {
      // No multicast route: nothing to add.
    } finally {
      socket?.close();
    }
    return assemble(messages);
  }

  /// "_googlecast._tcp" from "_googlecast._tcp.local".
  static String? _serviceType(String? name) {
    final m = RegExp(r'^(_[^.]+\._(?:tcp|udp))').firstMatch(name ?? '');
    return m?.group(1);
  }

  /// Turns responses into per-IP info. Records are tied to an IP through the
  /// SRV target's A record when there is one (a sleep proxy can answer for
  /// another host), otherwise the responder's own address.
  static Map<String, MdnsInfo> assemble(List<({String from, DnsMessage msg})> messages) {
    final hostIp = <String, String>{}; // host.local → ip
    final instanceHost = <String, String>{}; // instance full name → host.local
    for (final m in messages) {
      for (final r in m.msg.records) {
        final a = r.a;
        if (a != null) hostIp[r.name.toLowerCase()] = a;
        final srv = r.srv;
        if (srv != null) instanceHost[r.name] = srv.target.toLowerCase();
      }
    }
    final out = <String, MdnsInfo>{};
    MdnsInfo infoFor(String instanceFullName, String from) {
      final host = instanceHost[instanceFullName];
      final ip = (host == null ? null : hostIp[host]) ?? from;
      return out.putIfAbsent(ip, MdnsInfo.new);
    }

    for (final m in messages) {
      for (final r in m.msg.records) {
        final ptr = r.ptr;
        if (ptr != null && !r.name.startsWith('_services._dns-sd') && !r.name.endsWith('in-addr.arpa')) {
          final type = _serviceType(r.name);
          if (type == null) continue;
          final info = infoFor(ptr, m.from);
          info.types.add(type);
          final label = serviceLabels[type];
          if (label != null && label != 'Device info') info.services.add(label);
          final instance = instanceName(ptr, type);
          if (instance != null) {
            final mac = RegExp(r'\[((?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2})\]').firstMatch(instance)?.group(1);
            if (mac != null) info.mac = mac.toUpperCase();
            info.instances.add(_tidy(instance, type));
          }
          final host = instanceHost[ptr];
          if (host != null) info.host ??= host.replaceAll(RegExp(r'\.local\.?$'), '');
        }
        final srv = r.srv;
        if (srv != null) {
          infoFor(r.name, m.from).host ??= srv.target.replaceAll(RegExp(r'\.local\.?$'), '');
        }
        final txt = r.txt;
        if (txt.isNotEmpty) {
          final info = infoFor(r.name, m.from);
          final fn = txt['fn'];
          if (fn != null && fn.isNotEmpty) info.friendlyName ??= fn;
          final model = _model(txt);
          if (model != null) info.model ??= model;
        }
      }
    }
    out.removeWhere((_, v) => v.types.isEmpty && v.model == null && v.host == null);
    return out;
  }

  /// "Living Room" from "Living Room._googlecast._tcp.local".
  static String? instanceName(String full, String type) {
    final i = full.indexOf('.$type');
    return i <= 0 ? null : full.substring(0, i);
  }

  // "AA11BB22CC33@Kitchen" (RAOP) → "Kitchen"; "host [aa:bb…]" → "host".
  static String _tidy(String instance, String type) {
    var s = instance;
    if (type == '_raop._tcp' && s.contains('@')) s = s.substring(s.indexOf('@') + 1);
    return s.replaceAll(RegExp(r'\s*\[[0-9a-fA-F:]{17}\]$'), '').trim();
  }

  /// A model string from the usual TXT keys.
  static String? _model(Map<String, String> txt) {
    for (final k in const ['md', 'model', 'am', 'ty', 'usb_mdl', 'product', 'modelname']) {
      final v = txt[k]?.replaceAll(RegExp(r'^\(|\)$'), '').trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }
}
