/// Mobile bottom tabs.
enum MobileTab { ping, net, tools, history }

/// A top-level destination. The desktop sidebar lists all twelve, numbered.
class WireDestination {
  const WireDestination(this.index, this.label, this.path, this.tab);
  final String index;
  final String label;
  final String path;

  /// The mobile tab that stays highlighted while this screen is visible.
  final MobileTab tab;
}

class Routes {
  Routes._();
  static const launch = '/launch';
  static const ping = '/ping';
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
  static const tools = '/tools';
}

const kDestinations = <WireDestination>[
  WireDestination('01', 'Ping', Routes.ping, MobileTab.ping),
  WireDestination('02', 'Traceroute', Routes.traceroute, MobileTab.tools),
  WireDestination('03', 'Port scan', Routes.ports, MobileTab.tools),
  WireDestination('04', 'Speed test', Routes.speed, MobileTab.tools),
  WireDestination('05', 'Packet loss', Routes.loss, MobileTab.tools),
  WireDestination('06', 'Network', Routes.network, MobileTab.net),
  WireDestination('07', 'LAN scan', Routes.lan, MobileTab.net),
  WireDestination('08', 'Geo IP', Routes.geo, MobileTab.tools),
  WireDestination('09', 'Monitor', Routes.monitor, MobileTab.tools),
  WireDestination('10', 'Alerts', Routes.alerts, MobileTab.tools),
  WireDestination('11', 'History', Routes.history, MobileTab.history),
  WireDestination('12', 'Settings', Routes.settings, MobileTab.tools),
];

const kTabRoots = <MobileTab, String>{
  MobileTab.ping: Routes.ping,
  MobileTab.net: Routes.network,
  MobileTab.tools: Routes.tools,
  MobileTab.history: Routes.history,
};

/// The destination whose path prefixes [location], if any.
WireDestination? destinationFor(String location) {
  WireDestination? best;
  for (final d in kDestinations) {
    if (location == d.path || location.startsWith('${d.path}/')) {
      if (best == null || d.path.length > best.path.length) best = d;
    }
  }
  return best;
}

MobileTab tabFor(String location) {
  if (location.startsWith(Routes.tools)) return MobileTab.tools;
  return destinationFor(location)?.tab ?? MobileTab.ping;
}
