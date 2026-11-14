import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/providers/lan_provider.dart';
import 'package:pulse/services/net/lan/dns_wire.dart';
import 'package:pulse/services/net/lan/lan_scanner.dart';
import 'package:pulse/services/net/lan/mdns_browser.dart';
import 'package:pulse/services/net/lan/router_names.dart';
import 'package:pulse/services/net/lan/ssdp.dart';

// --- A tiny DNS response encoder for building test packets -----------------

List<int> _name(String n) => [
  for (final l in n.split('.').where((l) => l.isNotEmpty)) ...[utf8.encode(l).length, ...utf8.encode(l)],
  0,
];

List<int> _rr(String name, int type, List<int> data) => [
  ..._name(name),
  type >> 8,
  type & 0xFF,
  0x00,
  0x01,
  0,
  0,
  0x0E,
  0x10,
  data.length >> 8,
  data.length & 0xFF,
  ...data,
];

List<int> ptr(String name, String target) => _rr(name, DnsType.ptr, _name(target));
List<int> srv(String name, String target, int port) =>
    _rr(name, DnsType.srv, [0, 0, 0, 0, port >> 8, port & 0xFF, ..._name(target)]);
List<int> a(String name, String ip) => _rr(name, DnsType.a, ip.split('.').map(int.parse).toList());
List<int> txt(String name, List<String> kv) => _rr(name, DnsType.txt, [
  for (final s in kv) ...[utf8.encode(s).length, ...utf8.encode(s)],
]);

DnsMessage response(List<List<int>> records, {int id = 0}) {
  final bytes = <int>[id >> 8, id & 0xFF, 0x84, 0x00, 0, 0, records.length >> 8, records.length & 0xFF, 0, 0, 0, 0];
  for (final r in records) {
    bytes.addAll(r);
  }
  return DnsMessage.parse(Uint8List.fromList(bytes))!;
}

void main() {
  group('DNS wire', () {
    test('a query is a well-formed message with the right questions', () {
      final q = DnsWire.query(0x1234, [
        (name: DnsWire.reverseName('192.168.0.31'), type: DnsType.ptr),
      ], recursion: true);
      expect(q[0], 0x12);
      expect(q[1], 0x34);
      expect(q[2] & 0x01, 1, reason: 'RD set for unicast DNS');
      expect(q[5], 1, reason: 'one question');
      expect(utf8.decode(q.sublist(12), allowMalformed: true), contains('in-addr'));
    });

    test('records parse into PTR, SRV, TXT and A values', () {
      final m = response([
        ptr('31.0.168.192.in-addr.arpa', 'Galaxy-A24.lan'),
        srv('TV._googlecast._tcp.local', 'abc.local', 8009),
        txt('TV._googlecast._tcp.local', ['fn=Living Room TV', 'md=Chromecast']),
        a('abc.local', '192.168.0.40'),
      ], id: 7);
      expect(m.id, 7);
      expect(m.isResponse, isTrue);
      expect(m.records[0].ptr, 'Galaxy-A24.lan');
      expect(m.records[1].srv, (target: 'abc.local', port: 8009));
      expect(m.records[2].txt, {'fn': 'Living Room TV', 'md': 'Chromecast'});
      expect(m.records[3].a, '192.168.0.40');
    });

    test('compressed names are followed', () {
      // Name at offset 12, then a PTR whose target points back at it.
      final bytes = <int>[0, 1, 0x84, 0, 0, 0, 0, 1, 0, 0, 0, 0];
      final owner = _name('_ipp._tcp.local');
      bytes.addAll(owner);
      bytes.addAll([0x00, 0x0C, 0x00, 0x01, 0, 0, 0, 10]);
      final target = [7, ...utf8.encode('Printer'), 0xC0, 12];
      bytes.addAll([0, target.length, ...target]);
      // The owner name is the record name; rebuild the header count to 1 RR.
      final m = DnsMessage.parse(Uint8List.fromList(bytes))!;
      expect(m.records.single.ptr, 'Printer._ipp._tcp.local');
    });

    test('garbage does not throw', () {
      expect(DnsMessage.parse(Uint8List.fromList([1, 2, 3])), isNull);
      expect(DnsMessage.parse(Uint8List.fromList(List.filled(40, 0xC0))), isNotNull);
    });
  });

  group('Router DNS names', () {
    test('keeps real names and drops the domain', () {
      expect(RouterNames.clean('Galaxy-A24.lan.', '192.168.0.31'), 'Galaxy-A24');
      expect(RouterNames.clean('DESKTOP-4F2K.home', '192.168.0.12'), 'DESKTOP-4F2K');
    });

    test('drops names that only repeat the address (routers differ)', () {
      expect(RouterNames.clean('192-168-0-31.home', '192.168.0.31'), isNull);
      expect(RouterNames.clean('host-31.lan', '192.168.0.31'), isNull);
      expect(RouterNames.clean('dhcp31', '192.168.0.31'), isNull);
      expect(RouterNames.clean('192.168.0.31', '192.168.0.31'), isNull);
      expect(RouterNames.clean(null, '192.168.0.31'), isNull);
    });

    test('only private DNS servers are asked', () {
      expect(RouterNames.isPrivateIpv4('192.168.0.1'), isTrue);
      expect(RouterNames.isPrivateIpv4('10.0.0.1'), isTrue);
      expect(RouterNames.isPrivateIpv4('172.20.0.1'), isTrue);
      expect(RouterNames.isPrivateIpv4('8.8.8.8'), isFalse);
      expect(RouterNames.isPrivateIpv4('172.32.0.1'), isFalse);
    });
  });

  group('UPnP', () {
    test('SSDP headers are read case-insensitively', () {
      final h = Ssdp.parseHeaders(
        'HTTP/1.1 200 OK\r\nCACHE-CONTROL: max-age=1800\r\nLocation: http://192.168.0.1:1900/igd.xml\r\n'
        'SERVER: Linux/3.10 UPnP/1.0 TP-LINK/1.0\r\n\r\n',
      );
      expect(h['location'], 'http://192.168.0.1:1900/igd.xml');
      expect(h['server'], contains('TP-LINK'));
    });

    test('the root device is read, not an embedded one', () {
      const xml = '''<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0"><device>
  <deviceType>urn:schemas-upnp-org:device:InternetGatewayDevice:1</deviceType>
  <friendlyName>Archer C6</friendlyName>
  <manufacturer>TP-Link</manufacturer>
  <modelName>Archer C6</modelName>
  <modelNumber>2.0</modelNumber>
  <UDN>uuid:1234-abcd</UDN>
  <deviceList><device>
    <deviceType>urn:schemas-upnp-org:device:WANDevice:1</deviceType>
    <friendlyName>WANDevice</friendlyName>
  </device></deviceList>
</device></root>''';
      final i = Ssdp.parseDescription(xml);
      expect(i.friendlyName, 'Archer C6');
      expect(i.deviceKind, 'InternetGatewayDevice');
      expect(i.udn, 'uuid:1234-abcd');
      expect(i.model, 'TP-Link Archer C6 2.0');
      expect(
        Ssdp.parseDescription('<device><manufacturer>Roku</manufacturer><modelName>Roku Ultra</modelName></device>')
            .model,
        'Roku Ultra',
        reason: "the maker is already in the model name, so it isn't repeated",
      );
    });

    test('maker is added once and entities are decoded', () {
      final i = Ssdp.parseDescription(
        '<device><friendlyName>[TV] Samsung &amp; Co</friendlyName><manufacturer>Samsung Electronics</manufacturer>'
        '<modelName>QE55Q60</modelName></device>',
      );
      expect(i.friendlyName, '[TV] Samsung & Co');
      expect(i.model, 'Samsung Electronics QE55Q60');
      expect(LanScanner.cleanFriendlyName(i.friendlyName), 'Samsung & Co');
    });
  });

  group('mDNS', () {
    test('Google Cast: friendly name, model and the host IP from its A record', () {
      final info = MdnsBrowser.assemble([
        (
          from: '192.168.0.40',
          msg: response([
            ptr('_googlecast._tcp.local', 'Chromecast-1a2b3c4d5e6f7a8b9c0d._googlecast._tcp.local'),
            srv('Chromecast-1a2b3c4d5e6f7a8b9c0d._googlecast._tcp.local', 'cc-1234.local', 8009),
            txt('Chromecast-1a2b3c4d5e6f7a8b9c0d._googlecast._tcp.local', ['fn=Living Room TV', 'md=Chromecast']),
            a('cc-1234.local', '192.168.0.41'),
          ]),
        ),
      ]);
      // A sleep proxy can answer for another host: the A record wins.
      expect(info.keys, ['192.168.0.41']);
      final i = info['192.168.0.41']!;
      expect(i.name, 'Living Room TV');
      expect(i.model, 'Chromecast');
      expect(i.services, {'Google Cast'});
      expect(i.host, 'cc-1234');
    });

    test('AirPlay audio names drop the MAC prefix; workstation records give the MAC', () {
      final info = MdnsBrowser.assemble([
        (
          from: '192.168.0.50',
          msg: response([
            ptr('_raop._tcp.local', 'AA11BB22CC33@Kitchen._raop._tcp.local'),
            ptr('_workstation._tcp.local', 'nas [aa:bb:cc:dd:ee:ff]._workstation._tcp.local'),
          ]),
        ),
      ]);
      final i = info['192.168.0.50']!;
      expect(i.instances, containsAll(['Kitchen', 'nas']));
      expect(i.mac, 'AA:BB:CC:DD:EE:FF');
      expect(i.services, containsAll(['AirPlay audio', 'Computer']));
    });

    test('id-like instance names are not used as names', () {
      final info = MdnsBrowser.assemble([
        (from: '192.168.0.60', msg: response([ptr('_hap._tcp.local', '0123456789abcdef0123._hap._tcp.local')])),
      ]);
      expect(info['192.168.0.60']!.name, isNull);
      expect(info['192.168.0.60']!.services, {'HomeKit'});
    });
  });

  group('identify', () {
    test('self-reported names beat the router list, which beats system DNS', () {
      const h = LanHost(ip: '192.168.0.31', rttMs: 4);
      final both = LanScanner.identify(
        h,
        routerName: 'Galaxy-A24',
        probe: (mdns: null, netbios: 'PRANTA-PC', dns: 'something.isp.net'),
      );
      expect(both.hostname, 'PRANTA-PC');
      expect(both.sources, containsAll(['Ping', 'NetBIOS', 'Router DNS']));
      final router = LanScanner.identify(h, routerName: 'Galaxy-A24', probe: (mdns: null, netbios: null, dns: null));
      expect(router.hostname, 'Galaxy-A24');
      expect(router.identity, 'host:Galaxy-A24');
    });

    test('UPnP and mDNS fill friendly name, model, services and identity', () {
      final mdns = MdnsBrowser.assemble([
        (
          from: '192.168.0.40',
          msg: response([
            ptr('_googlecast._tcp.local', 'x._googlecast._tcp.local'),
            txt('x._googlecast._tcp.local', ['fn=Living Room TV', 'md=Chromecast']),
          ]),
        ),
      ])['192.168.0.40'];
      final h = LanScanner.identify(
        const LanHost(ip: '192.168.0.40'),
        upnp: const UpnpInfo(
          friendlyName: 'Living Room TV',
          manufacturer: 'Google',
          modelName: 'Chromecast',
          udn: 'uuid:cc',
          deviceType: 'urn:dial-multiscreen-org:device:dial:1',
        ),
        mdns: mdns,
        hintPorts: const [8009],
      );
      expect(h.friendlyName, 'Living Room TV');
      expect(h.model, 'Google Chromecast');
      expect(h.services, containsAll(['Google Cast']));
      expect(h.identity, 'uuid:cc');
      expect(h.sources, containsAll(['mDNS', 'UPnP', 'Ports']));
      expect(classifyDevice(h), DeviceType.tv);
    });

    test('Apple model ids become names people know', () {
      expect(LanScanner.prettyModel('MacBookPro18,1'), 'MacBook Pro');
      expect(LanScanner.prettyModel('AudioAccessory5,1'), 'HomePod');
      expect(LanScanner.prettyModel('Mac14,2'), 'Mac');
      expect(LanScanner.prettyModel('HP LaserJet M110w'), 'HP LaserJet M110w');
    });
  });

  group('classify', () {
    test('what a device says about itself wins', () {
      expect(classifyDevice(const LanHost(ip: '1', deviceKind: 'InternetGatewayDevice')), DeviceType.router);
      expect(classifyDevice(const LanHost(ip: '1', services: ['Printer'])), DeviceType.printer);
      expect(classifyDevice(const LanHost(ip: '1', hintPorts: [62078])), DeviceType.phone);
      expect(classifyDevice(const LanHost(ip: '1', model: 'MacBook Pro', services: ['AirPlay'])), DeviceType.pc);
      expect(classifyDevice(const LanHost(ip: '1', model: 'Nest Audio', services: ['Google Cast'])), DeviceType.audio);
      expect(classifyDevice(const LanHost(ip: '1', services: ['HomeKit'])), DeviceType.iot);
      expect(classifyDevice(const LanHost(ip: '1', hintPorts: [554])), DeviceType.camera);
    });

    test("a Windows PC's media renderer doesn't make it a TV", () {
      expect(classifyDevice(const LanHost(ip: '1', deviceKind: 'MediaRenderer', hintPorts: [3389])), DeviceType.pc);
      expect(classifyDevice(const LanHost(ip: '1', deviceKind: 'MediaRenderer')), DeviceType.tv);
    });
  });

  group('names', () {
    test('custom name, then friendly name, hostname, model, vendor, role', () {
      LanDevice d(LanHost h, [String? custom]) => LanDevice(host: h, type: DeviceType.unknown, customName: custom);
      const full = LanHost(ip: '1', friendlyName: 'Living Room TV', hostname: 'cc-1234', model: 'Chromecast');
      expect(d(full, "Mom's TV").displayName, "Mom's TV");
      expect(d(full).displayName, 'Living Room TV');
      expect(d(const LanHost(ip: '1', hostname: 'cc-1234', model: 'Chromecast')).displayName, 'cc-1234');
      expect(d(const LanHost(ip: '1', model: 'Chromecast')).displayName, 'Chromecast');
      expect(d(const LanHost(ip: '1', vendor: 'Samsung Electronics Co.,Ltd')).displayName, 'Samsung device');
      expect(d(const LanHost(ip: '1', isGateway: true)).displayName, 'Router');
      expect(d(const LanHost(ip: '1')).displayName, 'Unknown device');
      expect(d(const LanHost(ip: '1')).isUnknown, isTrue);
      expect(d(const LanHost(ip: '1'), 'Printer').isUnknown, isFalse);
    });
  });

  group('device type', () {
    test("the user's type wins over the detected one and is remembered by name", () {
      const d = LanDevice(
        host: LanHost(ip: '1'),
        type: DeviceType.unknown,
        customType: DeviceType.tv,
      );
      expect(d.kind, DeviceType.tv);
      expect(d.isUnknown, isFalse, reason: 'a picked type means the user knows what it is');
      expect(d.copyWith(clearCustomType: true).kind, DeviceType.unknown);
      // A port check reclassifies the device but must keep what the user set.
      const named = LanDevice(
        host: LanHost(ip: '1'),
        type: DeviceType.unknown,
        customName: 'Office phone',
      );
      final rechecked = named.copyWith(type: DeviceType.pc);
      expect(rechecked.customName, 'Office phone');
      expect(rechecked.type, DeviceType.pc);
      expect(LanDevice.typeFromName('printer'), DeviceType.printer);
      expect(LanDevice.typeFromName('nonsense'), isNull);
      expect(LanDevice.typeFromName(null), isNull);
    });
  });
}
