@Tags(['render'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/widgets/wire/wire.dart';
import 'package:pulse/presentations/screens/lan/lan_screen.dart';
import 'package:pulse/providers/lan_provider.dart';
import 'package:pulse/services/net/lan/lan_scanner.dart';
import 'package:pulse/services/net/port_scanner.dart';

import 'render_harness.dart';

LanDevice _d(String ip, String? name, String? vendor, double? rtt, {bool gw = false, bool self = false, bool isNew = false, String? mac}) {
  final h = LanHost(ip: ip, hostname: name, vendor: vendor, rttMs: rtt, isGateway: gw, isSelf: self, mac: mac);
  return LanDevice(host: h, type: classifyDevice(h), isNew: isNew, firstSeen: DateTime(2026, 9, 12, 9, 14));
}

class _Fake extends LanScanNotifier {
  _Fake(this.s);
  final LanScanState s;
  @override
  LanScanState build() => s;
}

void main() {
  setUpAll(loadWireFonts);

  final devices = [
    _d('192.168.1.1', null, 'TP-Link Systems Inc', 2, gw: true, mac: '28:87:BA:94:33:3B'),
    _d('192.168.1.10', 'realme-11-Pro', 'Realme Chongqing', 8),
    _d('192.168.1.24', 'ds220', 'Synology Incorporated', 3, mac: '00:11:32:A4:7E:0C'),
    _d('192.168.1.31', 'Living-TV', 'Samsung Electronics', 11),
    _d('192.168.1.42', 'Pranta-PC', 'Intel Corporate', 0, self: true),
    _d('192.168.1.52', 'ESP32-Plug', 'Espressif Inc.', 22),
    _d('192.168.1.60', 'HP-LaserJet', 'HP Inc.', 6),
    _d('192.168.1.77', null, null, null, isNew: true),
  ];
  final done = LanScanState(
    cidr: '192.168.1.0/24',
    total: 254,
    probed: 254,
    phase: 'done',
    elapsed: const Duration(milliseconds: 4800),
    devices: devices,
    selectedIp: '192.168.1.24',
    ports: const {
      '192.168.1.24': [
        PortResult(22, PortState.open),
        PortResult(80, PortState.open),
        PortResult(443, PortState.open),
        PortResult(5000, PortState.open),
      ],
    },
  );
  final scanning = LanScanState(
    cidr: '192.168.1.0/24',
    total: 254,
    probed: 182,
    phase: 'probing',
    current: '192.168.1.182',
    devices: devices.take(6).toList(),
  );

  Widget app(LanScanState s, Brightness b) => ProviderScope(
    overrides: [lanScanProvider.overrideWith(() => _Fake(s))],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildWireTheme(b),
      home: const Scaffold(body: LanScreen()),
    ),
  );

  testWidgets('lan screens', (tester) async {
    await renderToPng(tester, 'lan_desktop_light', app(done, Brightness.light), size: const Size(1060, 736));
    await renderToPng(tester, 'lan_desktop_dark', app(done, Brightness.dark), size: const Size(1060, 736));
    await renderToPng(tester, 'lan_mobile_scanning', app(scanning, Brightness.light), size: const Size(390, 780));
  });
}
