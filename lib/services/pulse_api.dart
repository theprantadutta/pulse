import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Client for Pulse's own backend (pulse-rust-api), which answers "what's my
/// public IP" and Geo IP lookups so the app talks to no third-party IP service.
///
/// The backend only serves this app: every request is signed with an HMAC of
/// the method, path, time and body using a key compiled in at build time:
///   flutter build appbundle --dart-define-from-file=secrets.json
/// `secrets.json` (git-ignored) holds `{"PULSE_APP_KEY": "..."}`, the same
/// value as PULSE_APP_KEY in the backend's .env.
class PulseApi {
  PulseApi({http.Client? client, String? baseUrl, String? key})
    : _client = client ?? http.Client(),
      _base = baseUrl ?? const String.fromEnvironment('PULSE_API_URL', defaultValue: 'https://pulse.pranta.dev'),
      _key = key ?? const String.fromEnvironment('PULSE_APP_KEY');

  final http.Client _client;
  final String _base;
  final String _key;

  /// False when the build has no app key (a plain `flutter run` without
  /// secrets.json): lookups then fail with a clear message instead of a 401.
  bool get configured => _key.isNotEmpty;

  /// Headers for one request: `X-Pulse-Time` and `X-Pulse-Signature`.
  Map<String, String> signHeaders(String method, String path, List<int> body, {DateTime? now}) {
    final time = ((now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000).toString();
    final message = '$method\n$path\n$time\n${sha256.convert(body)}';
    final sig = Hmac(sha256, utf8.encode(_key)).convert(utf8.encode(message)).toString();
    return {'x-pulse-time': time, 'x-pulse-signature': sig};
  }

  Future<Map<String, dynamic>> getJson(String path, {Duration timeout = const Duration(seconds: 6)}) async {
    _requireKey();
    final res = await _client
        .get(Uri.parse('$_base$path'), headers: signHeaders('GET', path, const []))
        .timeout(timeout);
    return _decode(res);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Object body, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    _requireKey();
    final bytes = utf8.encode(jsonEncode(body));
    final res = await _client
        .post(
          Uri.parse('$_base$path'),
          headers: {'content-type': 'application/json', ...signHeaders('POST', path, bytes)},
          body: bytes,
        )
        .timeout(timeout);
    return _decode(res);
  }

  void _requireKey() {
    if (!configured) throw const PulseApiException('This build has no Pulse API key (build with secrets.json).');
  }

  Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    final code = switch (res.statusCode) {
      401 => 'rejected the request (check the device clock)',
      429 => 'is busy, try again in a minute',
      503 => 'is starting up, try again shortly',
      _ => 'answered HTTP ${res.statusCode}',
    };
    throw PulseApiException('Pulse server $code');
  }
}

class PulseApiException implements Exception {
  const PulseApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
