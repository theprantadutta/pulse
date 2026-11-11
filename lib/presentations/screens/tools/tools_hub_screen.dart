import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/pulse/pulse.dart';
import '../../navigation/destinations.dart';
import '../../navigation/tools_catalog.dart';

/// 05 Tools hub: 8 tool tiles with their last result. Phone: 2-column grid of
/// 138 dp tiles. Tablet: 4 x 2 grid of large tiles filling the screen.
class ToolsHubScreen extends ConsumerWidget {
  const ToolsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(toolStatusProvider);
    final compact = context.isCompact;
    return PulsePage(
      title: 'Tools',
      large: true,
      subtitle: compact ? null : '8 tools · tap to open',
      actions: [
        if (compact)
          PulseIconButton(icon: PulseIcons.settings, tooltip: 'Settings', onPressed: () => context.go(Routes.settings))
        else
          PulseButton(
            label: 'Settings',
            icon: PulseIcons.settings,
            style: PulseButtonStyle.tonal,
            onPressed: () => context.go(Routes.settings),
          ),
      ],
      body: LayoutBuilder(
        builder: (context, box) {
          final columns = compact ? 2 : (box.maxWidth >= 720 ? 4 : 2);
          final rows = (kTools.length / columns).ceil();
          final pad = context.pagePadding;
          const gap = 12.0;
          // Tablets fill the height with the grid; phones use 138 dp tiles.
          final available = box.maxHeight - 4 - pad;
          final tileHeight = compact ? 138.0 : ((available - gap * (rows - 1)) / rows).clamp(150.0, 320.0);
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(pad, 4, pad, pad),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: compact ? 10 : gap,
              crossAxisSpacing: compact ? 10 : gap,
              mainAxisExtent: tileHeight,
            ),
            itemCount: kTools.length,
            itemBuilder: (context, i) => PulseEntrance(
              index: i,
              child: ToolTile(
                tool: kTools[i],
                status: status[kTools[i]] ?? ToolStatus(kTools[i].empty),
                large: !compact,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A tool tile: badge top-left, name and last result at the bottom. Monitor is
/// pink with a blinking "LIVE" label while monitoring runs.
class ToolTile extends StatelessWidget {
  const ToolTile({super.key, required this.tool, required this.status, this.large = false});

  final PulseTool tool;
  final ToolStatus status;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hot = status.live;
    final fg = hot ? c.onPrimaryFixed : c.onSurface;
    final sub = hot ? c.onPrimaryFixed : c.onSurfaceVariant;
    final badgeSize = large ? 72.0 : 44.0;
    final radius = hot ? (large ? 36.0 : 32.0) : 28.0;
    return Semantics(
      button: true,
      label: '${tool.name}, ${status.last}${hot ? ', live' : ''}',
      excludeSemantics: true,
      child: PulsePressable(
        onTap: () => context.go(tool.route),
        radius: radius,
        color: hot ? c.primaryFixedDim : c.surfaceContainer,
        child: Padding(
          padding: large ? const EdgeInsets.all(22) : const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hot)
                    // On the pink tile the badge inverts: dark diamond, pink icon.
                    PulseContainerBadge(
                      shape: tool.shape,
                      icon: tool.icon,
                      color: c.onPrimaryFixed,
                      onColor: c.primaryFixedDim,
                      size: badgeSize,
                    )
                  else
                    PulseShapeBadge(shape: tool.shape, tone: tool.tone, icon: tool.icon, size: badgeSize),
                  const Spacer(),
                  if (hot)
                    Row(
                      children: [
                        PulseLiveDot(color: fg, size: 7),
                        const SizedBox(width: 6),
                        Text('LIVE', style: pulseText(large ? 13 : 12, 800).copyWith(color: fg)),
                      ],
                    )
                  else if (large)
                    PulseIcon(PulseIcons.chevR, size: 22, color: c.onSurfaceVariant),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pulseText(large ? 28 : 19, 800, wdth: large ? 115 : 110, height: 1.15).copyWith(color: fg),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status.last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.bodySmall!.copyWith(fontSize: large ? 15 : 13, color: sub),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
