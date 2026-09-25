import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// MAC vendor lookup backed by the bundled IEEE registry extract
/// (assets/data/oui.tsv.gz, generated from Wireshark's `manuf`).
class OuiDb {
  OuiDb._(this._map);

  final Map<String, String> _map;

  static OuiDb? _instance;

  static Future<OuiDb> load({Uint8List? bytes}) async {
    if (_instance != null && bytes == null) return _instance!;
    final raw = bytes ?? (await rootBundle.load('assets/data/oui.tsv.gz')).buffer.asUint8List();
    final text = utf8.decode(GZipCodec().decode(raw));
    final map = <String, String>{};
    for (final line in const LineSplitter().convert(text)) {
      final tab = line.indexOf('\t');
      if (tab > 0) map[line.substring(0, tab)] = line.substring(tab + 1);
    }
    return _instance = OuiDb._(map);
  }

  /// Vendor for [mac] ("00:11:32:A4:7E:0C" / "00-11-32-…"), or null.
  String? vendor(String? mac) {
    if (mac == null) return null;
    final hex = mac.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
    if (hex.length < 6) return null;
    if (isRandomized(hex)) return 'Private address';
    // MA-S (36-bit) and MA-M (28-bit) blocks are more specific than MA-L.
    return _map[hex.substring(0, 9)] ?? _map[hex.substring(0, 7)] ?? _map[hex.substring(0, 6)];
  }

  /// Locally administered (randomised / private Wi-Fi) addresses.
  static bool isRandomized(String hexOrMac) {
    final hex = hexOrMac.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (hex.length < 2) return false;
    return (int.parse(hex.substring(0, 2), radix: 16) & 0x02) != 0;
  }
}
