import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/create_new_ping_screen.dart';
import '../screens/diagnostics_screen.dart';
import '../screens/network_info_screen.dart';
import '../screens/ping_screen.dart';
import '../screens/tools_screen.dart';
import 'bottom-navigation/bottom_navigation_layout.dart';

class AppNavigation {
  AppNavigation._();

  static String initial = PingScreen.kRouteName;

  // Private navigators
  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorPing = GlobalKey<NavigatorState>(
    debugLabel: 'shellPing',
  );
  static final _shellNavigatorNetworkInfo = GlobalKey<NavigatorState>(
    debugLabel: 'shellNetworkInfo',
  );
  static final _shellNavigatorDiagnostics = GlobalKey<NavigatorState>(
    debugLabel: 'shellDiagnostics',
  );
  static final _shellNavigatorTools = GlobalKey<NavigatorState>(
    debugLabel: 'shellTools',
  );

  // GoRouter configuration
  static final GoRouter router = GoRouter(
    initialLocation: initial,
    debugLogDiagnostics: true,
    navigatorKey: rootNavigatorKey,
    routes: [
      // /// OnBoardingScreen
      // GoRoute(
      //   parentNavigatorKey: rootNavigatorKey,
      //   path: OnBoardingScreen.route,
      //   name: "OnBoarding",
      //   builder: (context, state) => OnBoardingScreen(
      //     key: state.pageKey,
      //   ),
      // ),

      // /// OnBoardingThemeScreen
      // GoRoute(
      //   parentNavigatorKey: rootNavigatorKey,
      //   path: OnboardingThemeScreen.route,
      //   name: "OnBoardingTheme",
      //   builder: (context, state) => OnboardingThemeScreen(
      //     key: state.pageKey,
      //   ),
      // ),

      /// MainWrapper
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return BottomNavigationLayout(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          /// Branch Ping
          StatefulShellBranch(
            navigatorKey: _shellNavigatorPing,
            routes: <RouteBase>[
              GoRoute(
                path: PingScreen.kRouteName,
                name: "Ping",
                pageBuilder:
                    (context, state) => reusableTransitionPage(
                      state: state,
                      child: const PingScreen(),
                    ),
              ),
            ],
          ),

          StatefulShellBranch(
            navigatorKey: _shellNavigatorNetworkInfo,
            routes: <RouteBase>[
              GoRoute(
                path: NetworkInfoScreen.kRouteName,
                name: "NetworkInfo",
                pageBuilder:
                    (context, state) => reusableTransitionPage(
                      state: state,
                      child: const NetworkInfoScreen(),
                    ),
              ),
            ],
          ),

          StatefulShellBranch(
            navigatorKey: _shellNavigatorDiagnostics,
            routes: <RouteBase>[
              GoRoute(
                path: DiagnosticsScreen.kRouteName,
                name: "Diagnostics",
                pageBuilder:
                    (context, state) => reusableTransitionPage(
                      state: state,
                      child: const DiagnosticsScreen(),
                    ),
              ),
            ],
          ),

          StatefulShellBranch(
            navigatorKey: _shellNavigatorTools,
            routes: <RouteBase>[
              GoRoute(
                path: ToolsScreen.kRouteName,
                name: "Tools",
                pageBuilder:
                    (context, state) => reusableTransitionPage(
                      state: state,
                      child: const ToolsScreen(),
                    ),
              ),
            ],
          ),
        ],
      ),

      /// Create New Ping Screen
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: CreateNewPingScreen.kRouteName,
        name: "Create New Ping",
        builder: (context, state) => CreateNewPingScreen(key: state.pageKey),
      ),
    ],
  );

  static CustomTransitionPage<void> reusableTransitionPage({
    required state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      restorationId: state.pageKey.value,
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
}
