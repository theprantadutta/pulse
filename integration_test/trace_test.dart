// Full timeline trace of a few screens, for digging into slow frames.
//   flutter drive --profile --no-dds -d <serial> \
//     --driver=test_driver/perf_driver.dart --target=integration_test/trace_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/main.dart' as app;
import 'package:pulse/presentations/navigation/app_router.dart';
import 'package:pulse/presentations/navigation/destinations.dart';
import 'package:pulse/providers/lan_provider.dart';
import 'package:pulse/providers/ping_provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('trace screens', (tester) async {
    app.main(const []);
    await _wait(6);
    final container = ProviderScope.containerOf(tester.element(find.byType(PulseApp)));
    final router = container.read(routerProvider);
    final board = container.read(pingBoardProvider.notifier);
    await board.start('1.1.1.1', name: 'Cloudflare');

    // Per-widget build / layout spans (these flags work in profile builds).
    debugProfileBuildsEnabled = true;
    debugProfileLayoutsEnabled = true;
    router.go(Routes.lan);
    await _wait(1);
    await binding.traceAction(() async {
      await container.read(lanScanProvider.notifier).scan();
      await _wait(3);
    }, reportKey: 'timeline_lan');
    await board.stopAll();
  });
}

Future<void> _wait(int seconds) => Future<void>.delayed(Duration(seconds: seconds));
