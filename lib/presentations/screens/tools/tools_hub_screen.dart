import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/wire/wire.dart';
import '../../../core/widgets/wire/wire_page.dart';
import '../../../data/models/session_tool.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/monitor_summary_provider.dart';
import '../../navigation/destinations.dart';

/// 07 — Tools hub (mobile): every tool as a bordered tile with its last
/// result. The Monitor tile is signal while monitoring is live.
class ToolsHubScreen extends ConsumerWidget {
  const ToolsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final latest = ref.watch(latestSessionsProvider).value ?? const {};
    final monitor = ref.watch(monitorSummaryProvider).value;

    String last(SessionTool t, String empty) => latest[t]?.summary.isNotEmpty == true
        ? latest[t]!.summary
        : empty;

    final tiles = <_Tile>[
      _Tile('01', 'Ping', Routes.ping, last(SessionTool.ping, 'No runs yet')),
      _Tile('02', 'Traceroute', Routes.traceroute, last(SessionTool.trace, 'No runs yet')),
      _Tile('03', 'Port scan', Routes.ports, last(SessionTool.ports, 'No scans yet')),
      _Tile('04', 'Speed test', Routes.speed, last(SessionTool.speed, 'No tests yet')),
      _Tile('05', 'Packet loss', Routes.loss, last(SessionTool.loss, 'No tests yet')),
      _Tile('06', 'LAN scan', Routes.lan, last(SessionTool.lan, 'No scans yet')),
      _Tile('07', 'Geo IP', Routes.geo, last(SessionTool.geo, 'No lookups yet')),
      _Tile(
        '08',
        'Monitor',
        Routes.monitor,
        monitor == null || monitor.targets == 0
            ? 'No targets'
            : '${monitor.targets} target${monitor.targets == 1 ? '' : 's'}'
                  '${monitor.live ? ' · live' : ' · paused'}',
        signal: monitor?.live == true && monitor!.targets > 0,
      ),
    ];

    return WireMobilePage(
      header: WireMobileHeader(
        title: 'Tools',
        trailing: WirePressable(
          onTap: () => context.push(Routes.settings),
          tone: WireTone.ink,
          semanticLabel: 'Settings',
          builder: (context, c, s) => Container(
            color: c.bg,
            height: WireLayout.mobileHeader,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'SETTINGS',
              style: WireType.label(12).copyWith(
                color: s.contains(WidgetState.pressed) || s.contains(WidgetState.hovered)
                    ? c.fg
                    : w.signal,
              ),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          final rows = (tiles.length / 2).ceil();
          final tileHeight = ((box.maxHeight) / rows).clamp(120.0, 240.0);
          return SingleChildScrollView(
            child: Column(
              children: [
                for (var r = 0; r < rows; r++)
                  SizedBox(
                    height: tileHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _ToolTile(tile: tiles[r * 2], right: true)),
                        Expanded(child: _ToolTile(tile: tiles[r * 2 + 1])),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Tile {
  const _Tile(this.index, this.name, this.path, this.last, {this.signal = false});
  final String index;
  final String name;
  final String path;
  final String last;
  final bool signal;
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tile, this.right = false});
  final _Tile tile;
  final bool right;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return WireCell(
      onTap: () => context.push(tile.path),
      tone: tile.signal ? WireTone.signal : WireTone.plain,
      sides: WireSides(bottom: true, right: right),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      alignment: Alignment.topLeft,
      semanticLabel: tile.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(tile.index, style: WireType.label()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tile.name.toUpperCase(),
                style: WireType.display(26, width: 70, height: 0.95),
              ),
              const SizedBox(height: 2),
              Builder(
                builder: (context) {
                  final fg = DefaultTextStyle.of(context).style.color;
                  return Text(
                    tile.last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WireType.body(11).copyWith(
                      color: fg == w.ink ? w.text2 : fg,
                      height: 1.3,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
