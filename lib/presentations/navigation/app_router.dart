import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/wire_theme.dart';
import '../screens/geo/geo_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/lan/lan_screen.dart';
import '../screens/loss/loss_screen.dart';
import '../screens/launch/launch_screen.dart';
import '../screens/network/network_screen.dart';
import '../screens/ping/ping_screen.dart';
import '../screens/ports/ports_screen.dart';
import '../screens/speed/speed_screen.dart';
import '../screens/tools/tools_hub_screen.dart';
import '../screens/trace/trace_screen.dart';
import '../screens/tools_screen.dart';
import 'destinations.dart';
import 'wire_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Tab roots switch instantly; everything else slides in over 180ms on
/// mobile (a pushed tool with a ← back) and switches instantly on desktop.
Page<void> _page(BuildContext context, GoRouterState state, Widget child) {
  final isRoot = kTabRoots.values.contains(state.uri.path);
  final mobile = MediaQuery.sizeOf(context).width < WireLayout.compact;
  if (isRoot || !mobile) {
    return NoTransitionPage<void>(key: state.pageKey, child: child);
  }
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: WireMotion.panel,
    reverseTransitionDuration: WireMotion.panel,
    transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .chain(CurveTween(curve: WireMotion.panelCurve))
          .animate(animation),
      child: child,
    ),
  );
}

GoRoute _route(String path, Widget Function(GoRouterState s) build) => GoRoute(
  path: path,
  pageBuilder: (context, state) => _page(context, state, build(state)),
);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.launch,
    routes: [
      GoRoute(
        path: Routes.launch,
        pageBuilder: (context, state) =>
            NoTransitionPage(key: state.pageKey, child: const LaunchScreen()),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) =>
            WireShell(location: state.uri.path, child: child),
        routes: [
          _route(Routes.ping, (s) => const PingScreen()),
          _route(Routes.traceroute, (s) => TraceScreen(initialTarget: s.uri.queryParameters['target'])),
          _route(Routes.ports, (s) => PortsScreen(initialTarget: s.uri.queryParameters['target'])),
          _route(Routes.speed, (s) => const SpeedScreen()),
          _route(Routes.loss, (s) => LossScreen(initialTarget: s.uri.queryParameters['target'])),
          _route(Routes.network, (s) => const NetworkScreen()),
          _route(Routes.lan, (s) => const LanScreen()),
          _route(Routes.geo, (s) => GeoScreen(initialTarget: s.uri.queryParameters['target'])),
          _route(Routes.monitor, (s) => const ToolsScreen()),
          _route(Routes.alerts, (s) => const ToolsScreen()),
          _route(Routes.history, (s) => const HistoryScreen()),
          _route(Routes.settings, (s) => const ToolsScreen()),
          _route(Routes.tools, (s) => const ToolsHubScreen()),
        ],
      ),
    ],
  );
});
