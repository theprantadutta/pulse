import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Asks a LAN host for its own name: NetBIOS node status (Windows, Samba,
/// many NAS boxes) and unicast mDNS PTR (Apple, Android, Linux/Avahi).
class NameProbe {
  NameProbe._();

  static final _rand = DateTime.now().microsecondsSinceEpoch & 0xFFFF;

  /// NBSTAT query on UDP 137; returns the workstation name.
  static Future<String?> netbios(String ip, {Duration timeout = const Duration(milliseconds: 700)}) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final id = (_rand + ip.hashCode) & 0xFFFF;
      final q = BytesBuilder()
        ..add([id >> 8, id & 0xFF, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        // Encoded wildcard name "*" padded with NULs (first-level encoding).
        ..addByte(0x20)
        ..add(ascii.encode('CK${'A' * 30}'))
        ..addByte(0x00)
        ..add([0x00, 0x21, 0x00, 0x01]); // NBSTAT, IN
      socket.send(q.toBytes(), InternetAddress(ip), 137);
      final data = await _receive(socket, timeout);
      if (data == null || data.length < 57) return null;
      // Header 12 + name 34 + type/class/ttl/rdlength 10 = 56, then count.
      final count = data[56];
      var offset = 57;
      for (var i = 0; i < count && offset + 18 <= data.length; i++, offset += 18) {
        final name = ascii.decode(data.sublist(offset, offset + 15), allowInvalid: true).trim();
        final suffix = data[offset + 15];
        final flags = (data[offset + 16] << 8) | data[offset + 17];
        final group = (flags & 0x8000) != 0;
        if (suffix == 0x00 && !group && name.isNotEmpty) return name;
      }
      return null;
    } on Object {
      return null;
    } finally {
      socket?.close();
    }
  }

  /// Unicast DNS PTR query to the host's own mDNS responder (UDP 5353).
  static Future<String?> mdns(String ip, {Duration timeout = const Duration(milliseconds: 700)}) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final id = (_rand ^ ip.hashCode) & 0xFFFF;
      final b = BytesBuilder()
        ..add([id >> 8, id & 0xFF, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
      for (final label in [...ip.split('.').reversed, 'in-addr', 'arpa']) {
        b
          ..addByte(label.length)
          ..add(ascii.encode(label));
      }
      b
        ..addByte(0)
        ..add([0x00, 0x0C, 0x00, 0x01]); // PTR, IN
      socket.send(b.toBytes(), InternetAddress(ip), 5353);
      final data = await _receive(socket, timeout);
      if (data == null || data.length < 12) return null;
      final answers = (data[6] << 8) | data[7];
      if (answers == 0) return null;
      var o = _skipName(data, 12) + 4; // question
      o = _skipName(data, o);
      final type = (data[o] << 8) | data[o + 1];
      if (type != 0x0C) return null;
      final name = _readName(data, o + 10);
      return name?.replaceAll(RegExp(r'\.local\.?$'), '');
    } on Object {
      return null;
    } finally {
      socket?.close();
    }
  }

  static Future<Uint8List?> _receive(RawDatagramSocket socket, Duration timeout) {
    final c = Completer<Uint8List?>();
    late final StreamSubscription<RawSocketEvent> sub;
    final timer = Timer(timeout, () {
      if (!c.isCompleted) c.complete(null);
    });
    sub = socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final d = socket.receive();
        if (d != null && !c.isCompleted) c.complete(d.data);
      }
    });
    return c.future.whenComplete(() {
      timer.cancel();
      sub.cancel();
    });
  }

  static int _skipName(Uint8List d, int o) {
    while (o < d.length) {
      final len = d[o];
      if (len == 0) return o + 1;
      if ((len & 0xC0) == 0xC0) return o + 2;
      o += len + 1;
    }
    return o;
  }

  static String? _readName(Uint8List d, int o, [int depth = 0]) {
    if (depth > 8) return null;
    final labels = <String>[];
    while (o < d.length) {
      final len = d[o];
      if (len == 0) break;
      if ((len & 0xC0) == 0xC0) {
        final ptr = ((len & 0x3F) << 8) | d[o + 1];
        final rest = _readName(d, ptr, depth + 1);
        if (rest != null) labels.add(rest);
        break;
      }
      labels.add(utf8.decode(d.sublist(o + 1, o + 1 + len), allowMalformed: true));
      o += len + 1;
    }
    return labels.isEmpty ? null : labels.join('.');
  }
}

/// Wake-on-LAN magic packet.
class WakeOnLan {
  WakeOnLan._();

  static Future<void> wake(String mac, {List<String> broadcasts = const ['255.255.255.255']}) async {
    final hex = mac.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (hex.length != 12) throw ArgumentError('Invalid MAC address: $mac');
    final macBytes = [for (var i = 0; i < 12; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)];
    final packet = Uint8List.fromList([
      ...List.filled(6, 0xFF),
      for (var i = 0; i < 16; i++) ...macBytes,
    ]);
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    try {
      for (final b in broadcasts.toSet()) {
        for (final port in const [9, 7]) {
          socket.send(packet, InternetAddress(b), port);
        }
      }
    } finally {
      socket.close();
    }
  }
}
