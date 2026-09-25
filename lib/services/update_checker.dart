import 'dart:convert';

import 'package:http/http.dart' as http;

class UpdateInfo {
  const UpdateInfo({required this.latest, required this.url, required this.newer});
  final String latest;
  final String url;
  final bool newer;
}

/// Compares the running version with the latest GitHub release.
class UpdateChecker {
  const UpdateChecker();

  static const repo = 'theprantadutta/pulse';

  Future<UpdateInfo> check(String currentVersion) async {
    final res = await http
        .get(
          Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
          headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'Pulse'},
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) throw Exception('GitHub HTTP ${res.statusCode}');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (j['tag_name'] as String? ?? '').replaceFirst(RegExp('^v'), '');
    return UpdateInfo(
      latest: tag,
      url: j['html_url'] as String? ?? 'https://github.com/$repo/releases',
      newer: compareVersions(tag, currentVersion) > 0,
    );
  }
}

/// Semver-ish comparison of "1.2.3" strings (build metadata ignored).
int compareVersions(String a, String b) {
  List<int> parts(String v) =>
      v.split('+').first.split('-').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final x = parts(a), y = parts(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}
