import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart';
import 'package:vm_service/vm_service.dart' as vms;
import 'package:vm_service/vm_service_io.dart';

/// Writes each screen's frame summary from integration_test/perf_test.dart to
/// `build/perf/<PERF_DEVICE>/<screen>.json` (PERF_DEVICE defaults to "device").
///
/// Like `integrationDriver()`, except it connects to the isolate that runs the
/// test: with Monitor's background service on, the app has a second isolate
/// and `integrationDriver()` always takes the first one.
Future<void> main() async {
  final url = Platform.environment['VM_SERVICE_URL']!;
  final isolate = await _testIsolate(url);
  final driver = await FlutterDriver.connect(dartVmServiceUrl: url, isolateNumber: isolate);
  final json = await driver.requestData(null, timeout: const Duration(minutes: 30));
  final response = Response.fromJson(json);
  await driver.close();
  final data = response.data;
  if (data != null) {
    final dir = Directory('build/perf/${Platform.environment['PERF_DEVICE'] ?? 'device'}')..createSync(recursive: true);
    for (final e in data.entries) {
      File('${dir.path}/${e.key}.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(e.value));
    }
  }
  if (!response.allTestsPassed) {
    stderr.writeln(response.formattedFailureDetails);
    exit(1);
  }
  exit(0);
}

/// Number of the isolate that registered the driver extension.
Future<int?> _testIsolate(String httpUrl) async {
  final uri = Uri.parse(httpUrl);
  final ws = uri.replace(scheme: 'ws', path: '${uri.path.endsWith('/') ? uri.path : '${uri.path}/'}ws');
  final service = await vmServiceConnectUri(ws.toString());
  try {
    for (var attempt = 0; attempt < 60; attempt++) {
      final vm = await service.getVM();
      for (final ref in vm.isolates ?? const <vms.IsolateRef>[]) {
        final iso = await service.getIsolate(ref.id!);
        if (iso.extensionRPCs?.contains('ext.flutter.driver') ?? false) return int.tryParse(ref.number ?? '');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return null;
  } finally {
    await service.dispose();
  }
}
