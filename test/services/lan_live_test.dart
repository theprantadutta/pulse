@Tags(['network'])
library;

import 'dart:io';

import 'package:pulse/providers/connection_provider.dart';
import 'package:pulse/services/net/gateway.dart';
import 'package:pulse/services/net/lan/arp_table.dart';
import 'package:pulse/services/net/lan/lan_scanner.dart';
import 'package:pulse/services/net/lan/oui.dart';
import 'package:pulse/services/net/port_scanner.dart';
import 'package:test/test.dart';

void main() {
  test('OUI lookup', () async {
    final db = await OuiDb.load(bytes: File('assets/data/oui.tsv.gz').readAsBytesSync());
    expect(db.vendor('00:11:32:A4:7E:0C'), contains('Synology'));
    expect(db.vendor('B8-27-EB-00-00-01'), contains('Raspberry'));
    expect(db.vendor('DA:A1:19:00:00:00'), 'Private address');
  });

  test('ARP parser handles Windows, macOS and Linux formats', () {
    expect(ArpTable.parse('  192.168.0.1           28-87-ba-94-33-3b     dynamic'), {'192.168.0.1': '28:87:BA:94:33:3B'});
    expect(ArpTable.parse('? (10.0.0.1) at 0:1b:2c:3d:4e:5f on en0 ifscope [ethernet]'), {'10.0.0.1': '00:1B:2C:3D:4E:5F'});
    expect(ArpTable.parse('192.168.1.7 dev wlan0 lladdr aa:bb:cc:dd:ee:ff REACHABLE'), {'192.168.1.7': 'AA:BB:CC:DD:EE:FF'});
  });

  test('subnet helpers', () {
    expect(LanScanner.hostsFor('192.168.1.42', 24).length, 254);
    expect(LanScanner.cidrFor('192.168.1.42', 24), '192.168.1.0/24');
    expect(LanScanner.broadcastFor('192.168.1.42', 24), '192.168.1.255');
    expect(LanScanner.hostsFor('10.0.0.5', 8).length, 1022);
  });

  test('port spec parser', () {
    expect(parsePortSpec('22, 80,443 8000-8002'), [22, 80, 443, 8000, 8001, 8002]);
    expect(() => parsePortSpec('70000'), throwsFormatException);
  });

  test('real sweep of this LAN', () async {
    final ip = await primaryLocalIpv4();
    final gw = await Gateway.ipv4();
    await OuiDb.load(bytes: File('assets/data/oui.tsv.gz').readAsBytesSync());
    final sw = Stopwatch()..start();
    LanScanProgress? last;
    await for (final p in LanScanner().scan(localIp: ip!.$1, prefix: 24, gateway: gw)) {
      last = p;
    }
    // ignore: avoid_print
    print('sweep ${sw.elapsed.inMilliseconds} ms, ${last!.hosts.length} hosts');
    for (final h in last.hosts) {
      // ignore: avoid_print
      print('  ${h.ip.padRight(15)} ${(h.mac ?? '-').padRight(17)} ${(h.hostname ?? '-').padRight(24)} ${h.vendor ?? '-'}  '
          '${classifyDevice(h).label} ${h.rttMs?.toStringAsFixed(1) ?? 'arp'}${h.isGateway ? ' GW' : ''}${h.isSelf ? ' SELF' : ''}');
    }
    expect(last.hosts.any((h) => h.isGateway), isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('port scan of the gateway', () async {
    final gw = await Gateway.ipv4();
    final results = await const PortScanner().scan(InternetAddress(gw!), [22, 53, 80, 443, 8080]).toList();
    // ignore: avoid_print
    for (final r in results) {
      // ignore: avoid_print
      print('  ${r.port} ${r.state.name} ${r.banner ?? ''}');
    }
    expect(results, hasLength(5));
  });
}
