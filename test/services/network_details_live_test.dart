@Tags(['network'])
library;

import 'package:test/test.dart';
import 'package:pulse/providers/connection_provider.dart';
import 'package:pulse/services/net/geo_ip.dart';
import 'package:pulse/services/net/network_details.dart';

void main() {
  test('reads the real link on this machine', () async {
    final ip = await primaryLocalIpv4();
    final d = await const NetworkDetailsReader().read(
      summary: ConnectionSummary(kind: LinkKind.wifi, localIp: ip?.$1, interfaceName: ip?.$2),
    );
    // ignore: avoid_print
    print(
      'kind=${d.kind} name=${d.name} ssid=${d.ssid} std=${d.standard} band=${d.band} ch=${d.channel} '
      'sec=${d.security} sig=${d.signalDbm}dBm bars=${d.signalBars} link=${d.linkMbps} ip=${d.localIpv4} '
      'subnet=${d.subnetCidr} gw=${d.gateway} dns=${d.dns} mac=${d.mac} v6=${d.ipv6} vpn=${d.vpn}',
    );
    expect(d.kind, isNot(LinkKind.none));
    expect(d.localIpv4, isNotNull);
    expect(d.gateway, isNotNull);
  });

  test('geo lookup of a public IP', () async {
    final g = await GeoIpService().lookup('8.8.8.8');
    // ignore: avoid_print
    print('${g.ip} ${g.place} ${g.isp} ${g.asn} hosting=${g.hosting} via ${g.source}');
    expect(g.asn, 'AS15169');
  });

  test('channel/band helpers', () {
    expect(channelFromMhz(5220), 44);
    expect(bandFromMhz(5220), '5 GHZ');
    expect(channelFromMhz(2417), 2);
    expect(standardFromPhy('802.11ax'), 'WI-FI 6');
    expect(securityLabel('WPA2-Personal'), 'WPA2');
    expect(prefixFromMask('255.255.255.0'), 24);
  });
}
