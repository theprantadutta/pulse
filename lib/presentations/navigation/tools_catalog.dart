import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/pulse/pulse.dart';
import '../../data/models/session_tool.dart';
import '../../providers/database_provider.dart';
import '../../providers/monitor_summary_provider.dart';
import 'destinations.dart';

/// One tool in the Tools hub / Tools pane / History badges. Shape and colour
/// follow the kit's catalogue (prototype `P.TOOLS`) and stay the same wherever
/// the tool appears.
class PulseTool {
  const PulseTool({
    required this.name,
    required this.route,
    required this.icon,
    required this.shape,
    required this.tone,
    required this.empty,
    this.session,
  });

  final String name;
  final String route;
  final PulseIcons icon;
  final PulseShape shape;
  final PulseTone tone;

  /// Shown when the tool has never run.
  final String empty;

  /// The History session type this tool writes, if any.
  final SessionTool? session;
}

const kPingTool = PulseTool(
  name: 'Ping',
  route: Routes.ping,
  icon: PulseIcons.pulse,
  shape: PulseShape.cookie9,
  tone: PulseTone.pink,
  empty: 'Not run yet',
  session: SessionTool.ping,
);

const kMonitorTool = PulseTool(
  name: 'Monitor',
  route: Routes.monitor,
  icon: PulseIcons.monitor,
  shape: PulseShape.diamond,
  tone: PulseTone.lavender,
  empty: 'No targets',
);

const kTools = <PulseTool>[
  kPingTool,
  PulseTool(
    name: 'Traceroute',
    route: Routes.traceroute,
    icon: PulseIcons.route,
    shape: PulseShape.arch,
    tone: PulseTone.lavender,
    empty: 'Not run yet',
    session: SessionTool.trace,
  ),
  PulseTool(
    name: 'Port scan',
    route: Routes.ports,
    icon: PulseIcons.port,
    shape: PulseShape.square,
    tone: PulseTone.lime,
    empty: 'Not run yet',
    session: SessionTool.ports,
  ),
  PulseTool(
    name: 'Speed test',
    route: Routes.speed,
    icon: PulseIcons.gauge,
    shape: PulseShape.sunny,
    tone: PulseTone.pink,
    empty: 'Not run yet',
    session: SessionTool.speed,
  ),
  PulseTool(
    name: 'Packet loss',
    route: Routes.loss,
    icon: PulseIcons.loss,
    shape: PulseShape.clover4,
    tone: PulseTone.lavender,
    empty: 'Not run yet',
    session: SessionTool.loss,
  ),
  PulseTool(
    name: 'LAN scan',
    route: Routes.lan,
    icon: PulseIcons.lan,
    shape: PulseShape.pill,
    tone: PulseTone.lime,
    empty: 'Not run yet',
    session: SessionTool.lan,
  ),
  PulseTool(
    name: 'Geo IP',
    route: Routes.geo,
    icon: PulseIcons.pin,
    shape: PulseShape.circle,
    tone: PulseTone.pink,
    empty: 'Not run yet',
    session: SessionTool.geo,
  ),
  kMonitorTool,
];

/// The catalogue entry for a History session type.
PulseTool toolForSession(SessionTool session) =>
    kTools.firstWhere((t) => t.session == session, orElse: () => kPingTool);

/// The tool whose route [location] is under (Alerts counts as Monitor).
PulseTool? toolForLocation(String location) {
  if (location.startsWith(Routes.alerts)) return kMonitorTool;
  for (final t in kTools) {
    if (location == t.route || location.startsWith('${t.route}/')) return t;
  }
  return null;
}

class ToolStatus {
  const ToolStatus(this.last, {this.live = false});
  final String last;

  /// Monitor only: monitoring is running with at least one target.
  final bool live;
}

/// Last result line per tool ("21 hops · BD → SG"), "Not run yet" otherwise.
final toolStatusProvider = Provider<Map<PulseTool, ToolStatus>>((ref) {
  final latest = ref.watch(latestSessionsProvider).value ?? const {};
  final monitor = ref.watch(monitorSummaryProvider).value;
  return {
    for (final t in kTools)
      t: t == kMonitorTool
          ? ToolStatus(
              monitor == null || monitor.targets == 0
                  ? t.empty
                  : '${monitor.targets} target${monitor.targets == 1 ? '' : 's'}'
                        '${monitor.live ? ' · live' : ' · paused'}',
              live: monitor?.live == true && monitor!.targets > 0,
            )
          : ToolStatus((latest[t.session]?.summary.isNotEmpty ?? false) ? latest[t.session]!.summary : t.empty),
  };
});
