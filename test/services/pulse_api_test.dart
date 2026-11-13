import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulse/services/net/geo_ip.dart';
import 'package:pulse/services/pulse_api.dart';

void main() {
  final t = DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000);

  // Reference values computed independently (Python hmac/hashlib) with the
  // algorithm pulse-rust-api checks in src/geo.rs.
  test('signs requests exactly like the backend expects', () {
    final api = PulseApi(key: 'test-key', client: MockClient((_) async => http.Response('', 500)));
    final post = api.signHeaders('POST', '/api/v1/geo/lookup', utf8.encode('{"ips":["1.1.1.1"]}'), now: t);
    expect(post['x-pulse-time'], '1700000000');
    expect(post['x-pulse-signature'], '7de51325c1dc8fea7adc89a1f3b4f60ef5104b6f5c298f04fe4ffb8105da1e47');
    final get = api.signHeaders('GET', '/api/v1/ip', const [], now: t);
    expect(get['x-pulse-signature'], '4b310c05453ae181715009896b864913ee13f7bec475e1c711dd4eb142dfa2f2');
  });

  test('geo lookups send signed JSON and skip private results', () async {
    late http.Request sent;
    final client = MockClient((req) async {
      sent = req;
      return http.Response(
        jsonEncode({
          'results': [
            {
              'ip': '1.1.1.1',
              'city': 'Sydney',
              'countryCode': 'AU',
              'asn': 'AS13335',
              'asName': 'Cloudflare, Inc.',
              'public': true,
              'source': 'DB-IP',
            },
            {'ip': '192.168.0.1', 'public': false, 'source': 'DB-IP'},
          ],
        }),
        200,
      );
    });
    final geo = GeoIpService(
      api: PulseApi(client: client, key: 'k', baseUrl: 'https://example.test'),
    );
    final byIp = await geo.lookupMany(['1.1.1.1', '192.168.0.1']);
    expect(sent.url.toString(), 'https://example.test/api/v1/geo/lookup');
    expect(sent.headers['x-pulse-signature'], hasLength(64));
    expect(jsonDecode(sent.body), {
      'ips': ['1.1.1.1', '192.168.0.1'],
    });
    expect(byIp.keys, ['1.1.1.1']);
    expect(byIp['1.1.1.1']!.asn, 'AS13335');
    expect(byIp['1.1.1.1']!.source, 'DB-IP');
  });

  test('a build without the key fails clearly', () async {
    final geo = GeoIpService(
      api: PulseApi(key: '', client: MockClient((_) async => http.Response('{}', 200))),
    );
    expect(() => geo.lookup('1.1.1.1'), throwsA(isA<GeoLookupFailure>()));
  });

  test('server errors become readable messages', () async {
    final geo = GeoIpService(
      api: PulseApi(key: 'k', client: MockClient((_) async => http.Response('{}', 401))),
    );
    expect(
      () => geo.lookup('1.1.1.1'),
      throwsA(isA<GeoLookupFailure>().having((e) => e.message, 'message', contains('clock'))),
    );
  });
}
