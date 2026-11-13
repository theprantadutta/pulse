import 'dart:async';
import 'dart:io';

import '../pulse_api.dart';
import 'dns.dart';

/// Public IP facts: ISP, ASN and location.
class GeoInfo {
  const GeoInfo({
    required this.ip,
    this.city,
    this.region,
    this.country,
    this.countryCode,
    this.postal,
    this.lat,
    this.lon,
    this.timezone,
    this.isp,
    this.org,
    this.asn,
    this.asName,
    this.reverse,
    this.hosting,
    this.mobile,
    this.proxy,
    required this.source,
  });

  final String ip;
  final String? city, region, country, countryCode, postal, timezone;
  final double? lat, lon;
  final String? isp, org;

  /// "AS15169".
  final String? asn;
  final String? asName;
  final String? reverse;
  final bool? hosting, mobile, proxy;

  /// Where the facts came from: "DB-IP" (via Pulse's server) for new
  /// lookups; older history may say ip-api.com or ipinfo.io.
  final String source;

  GeoInfo withReverse(String name) => GeoInfo.fromJson({...toJson(), 'reverse': name});

  String get place =>
      [city, region, countryCode ?? country].whereType<String>().where((s) => s.isNotEmpty).toSet().join(', ');

  Map<String, Object?> toJson() => {
    'ip': ip,
    'city': city,
    'region': region,
    'country': country,
    'countryCode': countryCode,
    'postal': postal,
    'lat': lat,
    'lon': lon,
    'timezone': timezone,
    'isp': isp,
    'org': org,
    'asn': asn,
    'asName': asName,
    'reverse': reverse,
    'hosting': hosting,
    'mobile': mobile,
    'proxy': proxy,
    'source': source,
  };

  factory GeoInfo.fromJson(Map<String, dynamic> j) => GeoInfo(
    ip: j['ip'] as String,
    city: j['city'] as String?,
    region: j['region'] as String?,
    country: j['country'] as String?,
    countryCode: j['countryCode'] as String?,
    postal: j['postal'] as String?,
    lat: (j['lat'] as num?)?.toDouble(),
    lon: (j['lon'] as num?)?.toDouble(),
    timezone: j['timezone'] as String?,
    isp: j['isp'] as String?,
    org: j['org'] as String?,
    asn: j['asn'] as String?,
    asName: j['asName'] as String?,
    reverse: j['reverse'] as String?,
    hosting: j['hosting'] as bool?,
    mobile: j['mobile'] as bool?,
    proxy: j['proxy'] as bool?,
    source: j['source'] as String? ?? '',
  );
}

class GeoLookupFailure implements Exception {
  GeoLookupFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Public IP and Geo IP lookups through Pulse's own server (see PulseApi):
/// no third-party IP service. The server answers from DB-IP's free
/// databases; reverse DNS is asked of the device's own resolver.
class GeoIpService {
  GeoIpService({PulseApi? api}) : _api = api ?? PulseApi();
  final PulseApi _api;

  /// [ip] null means "my public IP".
  Future<GeoInfo> lookup([String? ip]) async {
    final List<GeoInfo> results;
    try {
      results = await _post(ip == null ? const [] : [ip]);
    } on PulseApiException catch (e) {
      throw GeoLookupFailure(e.message);
    } on TimeoutException {
      throw GeoLookupFailure('The Pulse server took too long to answer');
    } on SocketException {
      throw GeoLookupFailure("Couldn't reach the Pulse server");
    }
    if (results.isEmpty) throw GeoLookupFailure('No location found for ${ip ?? 'your IP'}');
    final g = results.first;
    final reverse = await Dns.reverse(g.ip);
    return reverse == null ? g : g.withReverse(reverse);
  }

  /// Several IPs in one request (traceroute hops). Missing entries were not
  /// found; failures throw.
  Future<Map<String, GeoInfo>> lookupMany(List<String> ips) async {
    if (ips.isEmpty) return const {};
    final results = await _post(ips);
    return {for (final g in results) g.ip: g};
  }

  Future<List<GeoInfo>> _post(List<String> ips) async {
    final j = await _api.postJson('/api/v1/geo/lookup', {'ips': ips});
    return [
      for (final r in (j['results'] as List? ?? const []).cast<Map<String, dynamic>>())
        if (r['public'] != false) GeoInfo.fromJson({...r, 'source': r['source'] ?? 'DB-IP'}),
    ];
  }

  /// The device's public IPv6 address, or null when the network has none.
  /// IPv6 has no NAT, so a global unicast address (2000::/3) on an interface
  /// is the address the internet sees: no outside service needed.
  ///
  /// Pass the active link's [interface] (e.g. `wlan0`): phones keep mobile
  /// data up while on Wi-Fi, and the SIM's address on `rmnet*` must not be
  /// shown next to the Wi-Fi ISP. When it is known, only that interface counts.
  Future<String?> publicIpv6({String? interface}) async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv6);
      return pickPublicIpv6({for (final i in interfaces) i.name: i.addresses}, interface: interface);
    } on Object {
      // No IPv6 stack or no permission: treat as no IPv6.
      return null;
    }
  }
}

/// The first global unicast IPv6 address on [interface], or on any interface
/// when [interface] is null (platforms that don't report it).
String? pickPublicIpv6(Map<String, List<InternetAddress>> byInterface, {String? interface}) {
  for (final MapEntry(key: name, value: addresses) in byInterface.entries) {
    if (interface != null && name != interface) continue;
    for (final a in addresses) {
      final first = a.rawAddress.isEmpty ? 0 : a.rawAddress[0];
      if ((first & 0xE0) == 0x20) return a.address.split('%').first;
    }
  }
  return null;
}
