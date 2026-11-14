import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// What a UPnP device says about itself in its description XML.
class UpnpInfo {
  const UpnpInfo({
    this.friendlyName,
    this.manufacturer,
    this.modelName,
    this.modelNumber,
    this.modelDescription,
    this.deviceType,
    this.udn,
    this.server,
  });

  /// "Living Room TV", "[TV] Samsung Q60 Series (55)".
  final String? friendlyName;
  final String? manufacturer;
  final String? modelName;
  final String? modelNumber;
  final String? modelDescription;

  /// urn:schemas-upnp-org:device:MediaRenderer:1 …
  final String? deviceType;

  /// uuid:… — stable across IP changes.
  final String? udn;

  /// The SSDP SERVER header ("Linux/4.9 UPnP/1.0 Roku/12.5").
  final String? server;

  /// "MediaRenderer" from the device-type URN.
  String? get deviceKind {
    final m = RegExp(r':device:([^:]+):').firstMatch(deviceType ?? '');
    return m?.group(1);
  }

  /// "Samsung QE55Q60" — maker and model, without repeating the maker.
  String? get model {
    final maker = manufacturer?.trim();
    var name = [
      modelName,
      modelNumber,
    ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().join(' ');
    if (name.isEmpty) name = modelDescription?.trim() ?? '';
    if (maker == null || maker.isEmpty) return name.isEmpty ? null : name;
    final short = maker.replaceAll(
      RegExp(r',?\s*(Inc|Ltd|Co|Corporation|Corp|LLC|GmbH)\.?$', caseSensitive: false),
      '',
    );
    if (name.isEmpty) return short;
    return name.toLowerCase().contains(short.toLowerCase().split(' ').first) ? name : '$short $name';
  }

  UpnpInfo withServer(String? s) => UpnpInfo(
    friendlyName: friendlyName,
    manufacturer: manufacturer,
    modelName: modelName,
    modelNumber: modelNumber,
    modelDescription: modelDescription,
    deviceType: deviceType,
    udn: udn,
    server: s ?? server,
  );
}

/// SSDP discovery: one multicast M-SEARCH, then each responder's description.
class Ssdp {
  Ssdp._();

  static final _group = InternetAddress('239.255.255.250');

  /// IP → what the device says about itself. Only IPs accepted by [inSubnet]
  /// are kept, and descriptions are only fetched from the responder itself.
  ///
  /// [unicast] hosts also get the search sent to them directly: routers and
  /// mesh systems that filter multicast between Wi-Fi clients still let a
  /// unicast M-SEARCH through.
  static Future<Map<String, UpnpInfo>> discover({
    required bool Function(String ip) inSubnet,
    List<String> unicast = const [],
    Duration listen = const Duration(milliseconds: 2500),
  }) async {
    final responses = <String, ({List<String> locations, String? server})>{};
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.multicastHops = 2;
      final sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final d = socket!.receive();
        if (d == null) return;
        final ip = d.address.address;
        if (!inSubnet(ip)) return;
        final headers = parseHeaders(utf8.decode(d.data, allowMalformed: true));
        final location = headers['location'];
        final prev = responses[ip];
        final locations = [...?prev?.locations];
        if (location != null && !locations.contains(location)) locations.add(location);
        responses[ip] = (locations: locations, server: prev?.server ?? headers['server']);
      });
      for (final st in const ['ssdp:all', 'upnp:rootdevice']) {
        socket.send(utf8.encode(_search(st)), _group, 1900);
      }
      for (final ip in unicast) {
        socket.send(utf8.encode(_search('ssdp:all', host: ip)), InternetAddress(ip), 1900);
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
      socket.send(utf8.encode(_search('ssdp:all')), _group, 1900);
      await Future<void>.delayed(listen - const Duration(milliseconds: 700));
      await sub.cancel();
    } on Object {
      // No multicast route (VPN, offline): nothing to add.
    } finally {
      socket?.close();
    }

    final out = <String, UpnpInfo>{};
    await Future.wait([
      for (final e in responses.entries)
        _describe(e.key, e.value.locations).then((info) {
          final i = (info ?? const UpnpInfo()).withServer(e.value.server);
          if (i.friendlyName != null || i.model != null || i.server != null) out[e.key] = i;
        }),
    ]);
    return out;
  }

  static String _search(String st, {String host = '239.255.255.250'}) =>
      'M-SEARCH * HTTP/1.1\r\n'
      'HOST: $host:1900\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: 2\r\n'
      'ST: $st\r\n'
      'USER-AGENT: Pulse UPnP/1.1\r\n\r\n';

  /// Lower-case header map of an SSDP response.
  static Map<String, String> parseHeaders(String text) {
    final out = <String, String>{};
    for (final line in text.split(RegExp(r'\r?\n')).skip(1)) {
      final i = line.indexOf(':');
      if (i > 0) out[line.substring(0, i).trim().toLowerCase()] = line.substring(i + 1).trim();
    }
    return out;
  }

  /// The first description that parses, from a LOCATION on the responder's
  /// own address (never another host).
  static Future<UpnpInfo?> _describe(String ip, List<String> locations) async {
    for (final location in locations) {
      final uri = Uri.tryParse(location);
      if (uri == null || uri.host != ip || !(uri.scheme == 'http' || uri.scheme == 'https')) continue;
      final xml = await _fetch(uri);
      if (xml == null) continue;
      final info = parseDescription(xml);
      if (info.friendlyName != null || info.model != null) return info;
    }
    return null;
  }

  static Future<String?> _fetch(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2)
      ..badCertificateCallback = (_, _, _) => true; // LAN devices use self-signed certs
    try {
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 2));
      final res = await req.close().timeout(const Duration(seconds: 2));
      if (res.statusCode != 200) return null;
      final bytes = <int>[];
      await for (final chunk in res.timeout(const Duration(seconds: 2))) {
        bytes.addAll(chunk);
        if (bytes.length > 128 * 1024) break;
      }
      return utf8.decode(bytes, allowMalformed: true);
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Reads the root device from a UPnP description document.
  static UpnpInfo parseDescription(String xml) {
    final start = xml.indexOf(RegExp('<device[ >]'));
    final root = start < 0 ? xml : xml.substring(start);
    // Fields of the root device come before its first embedded <deviceList>.
    final cut = root.indexOf('<deviceList');
    final own = cut < 0 ? root : root.substring(0, cut);
    String? tag(String name) {
      final m = RegExp('<$name>(.*?)</$name>', dotAll: true).firstMatch(own);
      final v = m == null ? null : decodeEntities(m.group(1)!.trim());
      return v == null || v.isEmpty ? null : v;
    }

    return UpnpInfo(
      friendlyName: tag('friendlyName'),
      manufacturer: tag('manufacturer'),
      modelName: tag('modelName'),
      modelNumber: tag('modelNumber'),
      modelDescription: tag('modelDescription'),
      deviceType: tag('deviceType'),
      udn: tag('UDN'),
    );
  }

  static String decodeEntities(String s) => s
      .replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '')
      .replaceAllMapped(RegExp(r'&#(x?)([0-9a-fA-F]+);'), (m) {
        final code = int.tryParse(m[2]!, radix: m[1]!.isEmpty ? 10 : 16);
        return code == null ? m[0]! : String.fromCharCode(code);
      })
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}
