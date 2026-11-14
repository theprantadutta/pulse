import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/pulse/pulse.dart';
import '../screens/alerts/alerts_screen.dart';
import '../screens/geo/geo_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/lan/lan_screen.dart';
import '../screens/loss/loss_screen.dart';
import '../screens/monitor/monitor_screen.dart';
import '../screens/network/network_screen.dart';
import '../screens/ping/ping_detail_screen.dart';
import '../screens/ping/ping_screen.dart';
import '../screens/ports/ports_screen.dart';
import '../screens/settings/about_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/speed/speed_screen.dart';
import '../screens/tools/tools_hub_screen.dart';
import '../screens/trace/trace_screen.dart';
import 'destinations.dart';
import 'pulse_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Top-level destinations (and everything on tablets/desktop) fade through:
/// the outgoing page fades out, the incoming one fades in from 96% scale.
/// Pushed tool screens on phones slide in by 30% while fading (expressive
/// shared axis). Reduce-motion makes every switch instant.
Page<void> _page(BuildContext context, GoRouterState state, Widget child) {
  final isRoot = kTabRoots.values.contains(state.uri.path);
  final compact = MediaQuery.sizeOf(context).width < PulseLayout.medium;
  if (PulseMotion.reduced(context)) return NoTransitionPage<void>(key: state.pageKey, child: child);
  if (isRoot || !compact) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondary, child) {
        final t = CurvedAnimation(parent: animation, curve: PulseMotion.emphasizedDecelerate);
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: const Interval(.25, 1)),
          child: ScaleTransition(scale: Tween(begin: .96, end: 1.0).animate(t), child: child),
        );
      },
    );
  }
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondary, child) {
      final t = CurvedAnimation(parent: animation, curve: PulseMotion.emphasizedDecelerate);
      return FadeTransition(
        opacity: t,
        child: SlideTransition(
          position: Tween(begin: const Offset(.3, 0), end: Offset.zero).animate(t),
          child: child,
        ),
      );
    },
  );
}

GoRoute _route(String path, Widget Function(GoRouterState s) build) =>
    GoRoute(path: path, pageBuilder: (context, state) => _page(context, state, build(state)));

/// Where the launch route goes once boot is done: the route the platform
/// asked for, or Ping. The Monitor notification launches Pulse with `/monitor`
/// (flutter_foreground_task's notificationInitialRoute).
String launchDestination(String platformRoute) {
  final uri = Uri.tryParse(platformRoute);
  if (uri == null || uri.path == '/' || uri.path == Routes.launch) return Routes.ping;
  return platformRoute;
}

final routerProvider = Provider<GoRouter>((ref) {
  final next = launchDestination(WidgetsBinding.instance.platformDispatcher.defaultRouteName);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.launch,
    // Always start on the launch route, even when the platform asks for
    // another one: SplashScreen runs boot (database, notifications, monitor)
    // and is what releases the native splash. Opening /monitor directly left
    // the first frame deferred forever, a blank screen.
    overridePlatformDefaultLocation: true,
    routes: [
      GoRoute(
        path: Routes.launch,
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: SplashScreen(next: next),
        ),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => PulseShell(location: state.uri.path, child: child),
        routes: [
          _route(Routes.ping, (s) => const PingScreen()),
          _route(Routes.pingDetail, (s) => PingDetailScreen(id: s.uri.queryParameters['id'])),
          _route(Routes.traceroute, (s) => TraceScreen(initialTarget: s.uri.queryParameters['target'])),
          _route(Routes.ports, (s) => PortsScreen(initialTarget: s.uri.queryParameters['target'])),
          _route(Routes.speed, (s) => const SpeedScreen()),
          _route(Routes.loss, (s) => LossScreen(initialTarget: s.uri.queryParameters['target'])),
          _route(Routes.network, (s) => const NetworkScreen()),
          _route(Routes.lan, (s) => const LanScreen()),
          _route(Routes.geo, (s) => GeoScreen(initialTarget: s.uri.queryParameters['target'])),
          _route(Routes.monitor, (s) => const MonitorScreen()),
          _route(Routes.alerts, (s) => const AlertsScreen()),
          _route(Routes.alertRule, (s) => RuleEditorScreen(ruleId: int.tryParse(s.uri.queryParameters['id'] ?? ''))),
          _route(Routes.history, (s) => const HistoryScreen()),
          _route(Routes.settings, (s) => const SettingsScreen()),
          _route(Routes.about, (s) => const AboutScreen()),
          _route(Routes.tools, (s) => const ToolsHubScreen()),
        ],
      ),
    ],
  );
});
