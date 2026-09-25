import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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

  /// ip-api.com or ipinfo.io.
  final String source;

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

/// Looks up IPs with ip-api.com (free, includes the hosting flag) and falls
/// back to ipinfo.io (HTTPS, needs IP_INFO_TOKEN in .env).
class GeoIpService {
  GeoIpService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _fields =
      'status,message,query,country,countryCode,regionName,city,zip,lat,lon,timezone,isp,org,as,asname,reverse,mobile,proxy,hosting';

  /// [ip] null means "my public IP".
  Future<GeoInfo> lookup([String? ip]) async {
    Object firstError;
    try {
      return await _ipApi(ip);
    } on Object catch (e) {
      firstError = e;
    }
    try {
      return await _ipInfo(ip);
    } on Object catch (e) {
      throw GeoLookupFailure('Lookup failed: $firstError; fallback: $e');
    }
  }

  Future<GeoInfo> _ipApi(String? ip) async {
    final uri = Uri.parse('http://ip-api.com/json/${ip ?? ''}?fields=$_fields');
    final res = await _client.get(uri).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) throw GeoLookupFailure('ip-api HTTP ${res.statusCode}');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (j['status'] != 'success') throw GeoLookupFailure('${j['message'] ?? 'ip-api failed'}');
    final as = j['as'] as String?;
    return GeoInfo(
      ip: j['query'] as String,
      city: j['city'] as String?,
      region: j['regionName'] as String?,
      country: j['country'] as String?,
      countryCode: j['countryCode'] as String?,
      postal: (j['zip'] as String?)?.isEmpty == true ? null : j['zip'] as String?,
      lat: (j['lat'] as num?)?.toDouble(),
      lon: (j['lon'] as num?)?.toDouble(),
      timezone: j['timezone'] as String?,
      isp: j['isp'] as String?,
      org: j['org'] as String?,
      asn: as == null ? null : RegExp(r'^(AS\d+)').firstMatch(as)?.group(1),
      asName: j['asname'] as String?,
      reverse: (j['reverse'] as String?)?.isEmpty == true ? null : j['reverse'] as String?,
      hosting: j['hosting'] as bool?,
      mobile: j['mobile'] as bool?,
      proxy: j['proxy'] as bool?,
      source: 'ip-api.com',
    );
  }

  Future<GeoInfo> _ipInfo(String? ip) async {
    final token = dotenv.isInitialized ? dotenv.maybeGet('IP_INFO_TOKEN') : null;
    final path = ip == null ? 'json' : '$ip/json';
    final uri = Uri.parse('https://ipinfo.io/$path${token == null || token.isEmpty ? '' : '?token=$token'}');
    final res = await _client.get(uri).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) throw GeoLookupFailure('ipinfo HTTP ${res.statusCode}');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (j['bogon'] == true) throw GeoLookupFailure('${j['ip']} is a private address');
    final org = j['org'] as String?;
    final asn = org == null ? null : RegExp(r'^(AS\d+)').firstMatch(org)?.group(1);
    final loc = (j['loc'] as String?)?.split(',');
    return GeoInfo(
      ip: j['ip'] as String,
      city: j['city'] as String?,
      region: j['region'] as String?,
      countryCode: j['country'] as String?,
      postal: j['postal'] as String?,
      lat: loc == null ? null : double.tryParse(loc[0]),
      lon: loc == null || loc.length < 2 ? null : double.tryParse(loc[1]),
      timezone: j['timezone'] as String?,
      isp: asn == null ? org : org!.substring(asn.length).trim(),
      org: org,
      asn: asn,
      reverse: j['hostname'] as String?,
      source: 'ipinfo.io',
    );
  }

  /// The public IPv6 address, or null when the network has no IPv6 path.
  Future<String?> publicIpv6() async {
    try {
      final res = await _client.get(Uri.parse('https://api6.ipify.org')).timeout(const Duration(seconds: 4));
      final v = res.body.trim();
      return res.statusCode == 200 && v.contains(':') ? v : null;
    } on Object {
      return null;
    }
  }
}
