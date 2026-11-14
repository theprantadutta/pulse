import 'dart:convert';
import 'dart:typed_data';

/// DNS record types Pulse reads.
abstract final class DnsType {
  static const a = 1;
  static const ptr = 12;
  static const txt = 16;
  static const srv = 33;
}

/// One resource record from a DNS / mDNS message, with typed readers.
class DnsRecord {
  DnsRecord._(this.name, this.type, this._message, this._offset, this._length);

  final String name;
  final int type;
  final Uint8List _message;
  final int _offset, _length;

  /// PTR target ("Living Room._googlecast._tcp.local").
  String? get ptr => type == DnsType.ptr ? DnsWire.readName(_message, _offset) : null;

  /// A record address ("192.168.0.31").
  String? get a => type == DnsType.a && _length == 4 ? _message.sublist(_offset, _offset + 4).join('.') : null;

  /// SRV target host and port.
  ({String target, int port})? get srv {
    if (type != DnsType.srv || _length < 7) return null;
    final port = (_message[_offset + 4] << 8) | _message[_offset + 5];
    final target = DnsWire.readName(_message, _offset + 6);
    return target == null ? null : (target: target, port: port);
  }

  /// TXT strings as key → value ("md" → "Chromecast"). Keys are lower-case.
  Map<String, String> get txt {
    if (type != DnsType.txt) return const {};
    final out = <String, String>{};
    var o = _offset;
    final end = _offset + _length;
    while (o < end) {
      final len = _message[o];
      if (o + 1 + len > end) break;
      final s = utf8.decode(_message.sublist(o + 1, o + 1 + len), allowMalformed: true);
      final eq = s.indexOf('=');
      if (eq > 0) out[s.substring(0, eq).toLowerCase()] = s.substring(eq + 1);
      o += 1 + len;
    }
    return out;
  }
}

/// A parsed message: its id and every answer, authority and additional record.
class DnsMessage {
  DnsMessage._(this.id, this.isResponse, this.records);

  final int id;
  final bool isResponse;
  final List<DnsRecord> records;

  /// Null when [data] isn't a well-formed DNS message.
  static DnsMessage? parse(Uint8List data) {
    try {
      if (data.length < 12) return null;
      final id = (data[0] << 8) | data[1];
      final response = (data[2] & 0x80) != 0;
      final qd = (data[4] << 8) | data[5];
      final rr = ((data[6] << 8) | data[7]) + ((data[8] << 8) | data[9]) + ((data[10] << 8) | data[11]);
      var o = 12;
      for (var i = 0; i < qd; i++) {
        o = DnsWire.skipName(data, o) + 4;
      }
      final records = <DnsRecord>[];
      for (var i = 0; i < rr && o < data.length; i++) {
        final name = DnsWire.readName(data, o) ?? '';
        o = DnsWire.skipName(data, o);
        if (o + 10 > data.length) break;
        final type = (data[o] << 8) | data[o + 1];
        final len = (data[o + 8] << 8) | data[o + 9];
        o += 10;
        if (o + len > data.length) break;
        records.add(DnsRecord._(name, type, data, o, len));
        o += len;
      }
      return DnsMessage._(id, response, records);
    } on Object {
      return null;
    }
  }
}

/// Builds queries and reads (compressed) names.
abstract final class DnsWire {
  /// A query for [questions]. [recursion] sets RD (unicast DNS); [unicastReply]
  /// sets the mDNS QU bit on every question.
  static Uint8List query(
    int id,
    List<({String name, int type})> questions, {
    bool recursion = false,
    bool unicastReply = false,
  }) {
    final b = BytesBuilder()
      ..add([id >> 8 & 0xFF, id & 0xFF, recursion ? 0x01 : 0x00, 0x00])
      ..add([questions.length >> 8, questions.length & 0xFF, 0, 0, 0, 0, 0, 0]);
    for (final q in questions) {
      for (final label in q.name.split('.').where((l) => l.isNotEmpty)) {
        final bytes = utf8.encode(label);
        b
          ..addByte(bytes.length)
          ..add(bytes);
      }
      b
        ..addByte(0)
        ..add([q.type >> 8, q.type & 0xFF, unicastReply ? 0x80 : 0x00, 0x01]);
    }
    return b.toBytes();
  }

  /// "31.0.168.192.in-addr.arpa" for 192.168.0.31.
  static String reverseName(String ipv4) => '${ipv4.split('.').reversed.join('.')}.in-addr.arpa';

  static int skipName(Uint8List d, int o) {
    while (o < d.length) {
      final len = d[o];
      if (len == 0) return o + 1;
      if ((len & 0xC0) == 0xC0) return o + 2;
      o += len + 1;
    }
    return o;
  }

  static String? readName(Uint8List d, int o, [int depth = 0]) {
    if (depth > 10) return null;
    final labels = <String>[];
    while (o < d.length) {
      final len = d[o];
      if (len == 0) break;
      if ((len & 0xC0) == 0xC0) {
        if (o + 1 >= d.length) return null;
        final rest = readName(d, ((len & 0x3F) << 8) | d[o + 1], depth + 1);
        if (rest != null) labels.add(rest);
        break;
      }
      if (o + 1 + len > d.length) return null;
      labels.add(utf8.decode(d.sublist(o + 1, o + 1 + len), allowMalformed: true));
      o += len + 1;
    }
    return labels.isEmpty ? null : labels.join('.');
  }
}
