// Frame-timing profile of every screen with its animations running.
//
// Run on a device in profile mode (one device at a time):
//   flutter drive --profile -d <serial> \
//     --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart
// Each screen's summary (build + raster times, missed frames) is written to
// build/perf/<device>/<screen>.json by the driver.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/main.dart' as app;
import 'package:pulse/presentations/navigation/app_router.dart';
import 'package:pulse/presentations/navigation/destinations.dart';
import 'package:pulse/providers/lan_provider.dart';
import 'package:pulse/providers/loss_provider.dart';
import 'package:pulse/providers/ping_provider.dart';
import 'package:pulse/providers/port_scan_provider.dart';
import 'package:pulse/providers/speed_provider.dart';
import 'package:pulse/providers/trace_provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Real frames at the display's rate, like a user sees them.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('profile every screen', (tester) async {
    app.main(const []);
    await _wait(6); // splash, first frames, network info

    final container = ProviderScope.containerOf(tester.element(find.byType(PulseApp)));
    final router = container.read(routerProvider);

    Future<void> screen(String name, String route, {int seconds = 5, Future<void> Function()? during}) async {
      router.go(route);
      await _wait(1); // let the route transition finish before measuring
      await binding.watchPerformance(() async {
        if (during != null) await during();
        await _wait(seconds);
      }, reportKey: name);
    }

    // Live pings drive the odometer digits, hero shape and bar charts.
    final board = container.read(pingBoardProvider.notifier);
    await board.start('1.1.1.1', name: 'Cloudflare');
    await board.start('8.8.8.8', name: 'Google DNS');
    await board.start('192.168.0.1', name: 'Router');

    await screen('ping_board', Routes.ping, seconds: 8);
    final id = container.read(pingBoardProvider).sessions.first.id;
    await screen('ping_detail', '${Routes.pingDetail}?id=${Uri.encodeQueryComponent(id)}', seconds: 8);
    await screen('network', Routes.network);
    await screen('tools', Routes.tools);
    await screen(
      'traceroute_running',
      Routes.traceroute,
      seconds: 15,
      during: () async => container.read(traceProvider.notifier).run('google.com'),
    );
    await screen(
      'port_scan_running',
      Routes.ports,
      seconds: 8,
      during: () async => container.read(portScanProvider.notifier).scan('192.168.0.1'),
    );
    await screen(
      'speed_test_running',
      Routes.speed,
      seconds: 25,
      during: () async => container.read(speedProvider.notifier).start(),
    );
    await screen(
      'packet_loss_running',
      Routes.loss,
      seconds: 10,
      during: () async => container.read(lossProvider.notifier).start('1.1.1.1'),
    );
    await screen(
      'lan_scan_running',
      Routes.lan,
      seconds: 15,
      during: () async => container.read(lanScanProvider.notifier).scan(),
    );
    await screen('geo_ip', Routes.geo, seconds: 6);
    await screen('monitor', Routes.monitor);
    await screen('alerts', Routes.alerts);
    await screen('history', Routes.history);
    await screen('settings', Routes.settings);
    await screen('about', Routes.about);

    // Scrolling + list entrance animations.
    router.go(Routes.history);
    await _wait(1);
    await binding.watchPerformance(() async {
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 3; i++) {
        await tester.fling(list, const Offset(0, -600), 2500);
        await _wait(1);
        await tester.fling(list, const Offset(0, 600), 2500);
        await _wait(1);
      }
    }, reportKey: 'history_scroll');

    // Tab switches: shared-axis transitions and entrances.
    await binding.watchPerformance(() async {
      for (final r in [Routes.ping, Routes.network, Routes.tools, Routes.history, Routes.ping]) {
        router.go(r);
        await _wait(1);
      }
    }, reportKey: 'tab_switches');

    await container.read(lossProvider.notifier).stop();
    await board.stopAll();
  });
}

Future<void> _wait(int seconds) => Future<void>.delayed(Duration(seconds: seconds));
