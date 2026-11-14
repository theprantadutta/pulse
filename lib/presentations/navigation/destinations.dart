/// Top-level destinations: phone bottom tabs and the tablet rail.
enum MobileTab { ping, net, tools, history }

class Routes {
  Routes._();
  static const launch = '/launch';
  static const ping = '/ping';

  /// Ping detail for one host: `/ping/host?id=<host id>`.
  static const pingDetail = '/ping/host';
  static const traceroute = '/traceroute';
  static const ports = '/ports';
  static const speed = '/speed';
  static const loss = '/loss';
  static const network = '/network';
  static const lan = '/lan';
  static const geo = '/geo';
  static const monitor = '/monitor';
  static const alerts = '/alerts';
  static const alertRule = '/alerts/rule';
  static const history = '/history';
  static const settings = '/settings';
  static const about = '/settings/about';
  static const support = '/settings/support';
  static const tools = '/tools';
}

const kTabRoots = <MobileTab, String>{
  MobileTab.ping: Routes.ping,
  MobileTab.net: Routes.network,
  MobileTab.tools: Routes.tools,
  MobileTab.history: Routes.history,
};

bool _under(String location, String path) => location == path || location.startsWith('$path/');

/// Screens pushed from the Tools hub (the Tools tab stays selected, and on
/// expanded layouts the Tools pane sits next to them).
const kToolRoutes = <String>[
  Routes.traceroute,
  Routes.ports,
  Routes.speed,
  Routes.loss,
  Routes.lan,
  Routes.geo,
  Routes.monitor,
  Routes.alerts,
];

bool isToolRoute(String location) => kToolRoutes.any((p) => _under(location, p));

/// The tab (or rail destination) highlighted for [location]. Settings has its
/// own rail entry, so it returns null there on tablets; on phones Settings
/// opens from the Tools hub and keeps Tools selected (see [tabFor]).
MobileTab? railTabFor(String location) {
  if (_under(location, Routes.settings)) return null;
  return tabFor(location);
}

MobileTab tabFor(String location) {
  if (_under(location, Routes.ping)) return MobileTab.ping;
  if (_under(location, Routes.network)) return MobileTab.net;
  if (_under(location, Routes.history)) return MobileTab.history;
  return MobileTab.tools;
}

/// Where system back goes when nothing was pushed (deep links, `go` from the
/// rail or Tools pane): tool screens → Tools, Alerts → Monitor, the rule
/// editor → Alerts, Ping detail → Ping, the other tabs → Ping. Null on Ping:
/// back leaves the app from there.
String? parentRoute(String location) {
  if (_under(location, Routes.about)) return Routes.settings;
  if (_under(location, Routes.support)) return Routes.settings;
  if (_under(location, Routes.alertRule)) return Routes.alerts;
  if (_under(location, Routes.alerts)) return Routes.monitor;
  if (_under(location, Routes.pingDetail)) return Routes.ping;
  if (_under(location, Routes.ping)) return null;
  if (_under(location, Routes.settings) || isToolRoute(location)) return Routes.tools;
  return Routes.ping;
}
