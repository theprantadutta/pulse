import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/pulse/pulse.dart';
import 'destinations.dart';
import 'tools_catalog.dart';

const _tabs = <MobileTab, (String, PulseIcons)>{
  MobileTab.ping: ('Ping', PulseIcons.pulse),
  MobileTab.net: ('Network', PulseIcons.wifi),
  MobileTab.tools: ('Tools', PulseIcons.grid),
  MobileTab.history: ('History', PulseIcons.clock),
};

/// App frame (SCREENS.md "Information architecture").
///
/// * compact: content plus an 80 dp NavigationBar with 4 tabs.
/// * medium / expanded: a 96 dp rail (brand, "+", 4 destinations, Settings at
///   the bottom). On expanded layouts tool screens get the Tools pane beside
///   them, replacing the old numbered rail.
class PulseShell extends StatelessWidget {
  const PulseShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final compact = context.isCompact;
    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: compact ? c.surfaceContainer : c.surface,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    );

    final Widget frame;
    if (compact) {
      final active = tabFor(location);
      frame = Scaffold(
        backgroundColor: c.surface,
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: MobileTab.values.indexOf(active),
          onDestinationSelected: (i) {
            final tab = MobileTab.values[i];
            HapticFeedback.selectionClick();
            context.go(kTabRoots[tab]!);
          },
          destinations: [
            for (final tab in MobileTab.values)
              NavigationDestination(icon: PulseIcon(_tabs[tab]!.$2), label: _tabs[tab]!.$1, tooltip: ''),
          ],
        ),
      );
    } else {
      final showPane = context.isExpanded && isToolRoute(location);
      frame = Scaffold(
        backgroundColor: c.surface,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Rail(location: location),
              if (showPane) ToolsPane(selected: toolForLocation(location)),
              Expanded(child: child),
            ],
          ),
        ),
      );
    }
    // System back with nothing left to pop in the shell navigator walks up to
    // the screen's parent instead of closing the app (see [parentRoute]).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final parent = parentRoute(location);
        if (parent == null) {
          SystemNavigator.pop();
        } else {
          context.go(parent);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(value: overlay, child: frame),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = railTabFor(location);
    final onSettings = location.startsWith(Routes.settings);
    return SizedBox(
      width: PulseLayout.rail,
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Tooltip(
                    message: 'Pulse',
                    child: GestureDetector(
                      onTap: () => context.go(Routes.ping),
                      child: const PulseLogo(size: 48, tile: true),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Tooltip(
                    message: 'New ping',
                    child: Semantics(
                      button: true,
                      label: 'New ping',
                      excludeSemantics: true,
                      child: PulsePressable(
                        onTap: () => context.go('${Routes.ping}?add=1'),
                        radius: 16,
                        color: c.primaryContainer,
                        child: SizedBox.square(
                          dimension: 56,
                          child: Center(child: PulseIcon(PulseIcons.plus, size: 24, color: c.onPrimaryContainer)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (final tab in MobileTab.values)
                    _RailItem(
                      label: _tabs[tab]!.$1,
                      icon: _tabs[tab]!.$2,
                      selected: tab == active,
                      onTap: () => context.go(kTabRoots[tab]!),
                    ),
                  const Spacer(),
                  _RailItem(
                    label: 'Settings',
                    icon: PulseIcons.settings,
                    selected: onSettings,
                    onTap: () => context.go(Routes.settings),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final PulseIcons icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        customBorder: const StadiumBorder(),
        child: SizedBox(
          width: 80,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: PulseMotion.shapeMorph,
                curve: PulseMotion.spring,
                width: selected ? 56 : 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? c.secondaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: PulseIcon(icon, size: 22, color: selected ? c.onSecondaryContainer : c.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: context.type.labelMedium!.copyWith(
                  color: selected ? c.onSurface : c.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tablet Tools pane: all 8 tools with their last result next to a tool screen.
class ToolsPane extends ConsumerWidget {
  const ToolsPane({super.key, this.selected});
  final PulseTool? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(toolStatusProvider);
    final c = context.colors;
    return PulsePane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulsePaneHeader(
            title: 'Tools',
            actions: [
              PulseIconButton(
                icon: PulseIcons.settings,
                tooltip: 'Settings',
                onPressed: () => context.go(Routes.settings),
              ),
            ],
          ),
          Expanded(
            child: ListView.separated(
              itemCount: kTools.length,
              separatorBuilder: (_, _) => const SizedBox(height: 3),
              itemBuilder: (context, i) {
                final t = kTools[i];
                final on = t == selected;
                return PulseEntrance(
                  index: i,
                  fromLeft: true,
                  child: Semantics(
                    button: true,
                    selected: on,
                    label: '${t.name}, ${status[t]?.last ?? t.empty}',
                    excludeSemantics: true,
                    child: PulsePressable(
                      onTap: () => context.go(t.route),
                      radius: on ? 28 : 16,
                      color: on ? c.secondaryContainer : Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                        child: Row(
                          children: [
                            PulseShapeBadge(shape: t.shape, tone: t.tone, icon: t.icon),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.name,
                                    style: context.type.titleMedium!.copyWith(
                                      color: on ? c.onSecondaryContainer : c.onSurface,
                                    ),
                                  ),
                                  Text(
                                    status[t]?.last ?? t.empty,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.type.labelMedium!.copyWith(
                                      fontWeight: FontWeight.w400,
                                      color: on ? c.onSecondaryContainer.withValues(alpha: .85) : c.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
