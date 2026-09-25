import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/brand/pulse_mark.dart';
import '../../core/widgets/wire/wire.dart';
import '../../core/widgets/wire/wire_page.dart';
import '../../providers/connection_provider.dart';
import 'destinations.dart';

/// App frame: numbered sidebar (desktop), index rail (compact) or bordered
/// container + 4-cell tab bar (mobile).
class WireShell extends StatelessWidget {
  const WireShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final mode = context.wireMode;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: w.background,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    );

    final Widget body = switch (mode) {
      WireMode.desktop => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: WireLayout.sidebar,
            child: _Sidebar(location: location),
          ),
          Container(width: kWireBorder, color: w.ink),
          Expanded(child: child),
        ],
      ),
      WireMode.compact => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: WireLayout.rail,
            child: _Rail(location: location),
          ),
          Container(width: kWireBorder, color: w.ink),
          Expanded(child: child),
        ],
      ),
      WireMode.mobile => SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: WireBox(clip: true, child: child),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: _TabBar(location: location),
            ),
          ],
        ),
      ),
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(backgroundColor: w.background, resizeToAvoidBottomInset: mode == WireMode.mobile, body: body),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.location});
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final current = destinationFor(location);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LogoCell(onTap: () => context.go(Routes.ping)),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final d in kDestinations)
                  WireCell(
                    selected: d == current,
                    onTap: () => context.go(d.path),
                    sides: WireSides.onlyBottom,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    semanticLabel: d.label,
                    child: Row(
                      children: [
                        Expanded(child: Text(d.label.toUpperCase(), style: WireType.nav(17))),
                        Text(d.index, style: WireType.body(11).copyWith(height: 1)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: w.ink, width: kWireBorder),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: const _ConnectionFooter(),
        ),
      ],
    );
  }
}

class _LogoCell extends StatelessWidget {
  const _LogoCell({required this.onTap, this.compact = false});
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return WirePressable(
      onTap: onTap,
      tone: WireTone.signal,
      semanticLabel: 'Pulse',
      builder: (context, c, s) => Container(
        height: WireLayout.topBar,
        decoration: BoxDecoration(
          color: w.signal,
          border: Border(
            bottom: BorderSide(color: w.ink, width: kWireBorder),
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 20),
        alignment: compact ? Alignment.center : Alignment.centerLeft,
        child: compact ? const PulseMark(size: 34) : const PulseLockup(height: 34),
      ),
    );
  }
}

class _ConnectionFooter extends ConsumerWidget {
  const _ConnectionFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final conn = ref.watch(connectionProvider).value;
    final online = conn?.online ?? false;
    final name = conn?.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '● ',
                style: TextStyle(color: online ? w.ink : w.signal),
              ),
              TextSpan(
                text: conn == null
                    ? 'CHECKING…'
                    : [conn.kindLabel, if (name != null && name.isNotEmpty) name.toUpperCase()].join(' / '),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: WireType.data(12).copyWith(color: w.ink),
        ),
        const SizedBox(height: 3),
        Text(
          conn?.localIp ?? (online ? '—' : 'No connection'),
          style: WireType.body(12).copyWith(color: w.ink, height: 1.2),
        ),
      ],
    );
  }
}

class _Rail extends ConsumerWidget {
  const _Rail({required this.location});
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final current = destinationFor(location);
    final online = ref.watch(connectionProvider).value?.online ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LogoCell(onTap: () => context.go(Routes.ping), compact: true),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final d in kDestinations)
                  WireCell(
                    selected: d == current,
                    onTap: () => context.go(d.path),
                    sides: WireSides.onlyBottom,
                    tooltip: d.label,
                    semanticLabel: d.label,
                    alignment: Alignment.center,
                    padding: EdgeInsets.zero,
                    height: 48,
                    child: Text(d.index, style: WireType.nav(18)),
                  ),
              ],
            ),
          ),
        ),
        Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: w.ink, width: kWireBorder),
            ),
          ),
          child: Text('●', style: WireType.data(14).copyWith(color: online ? w.ink : w.signal)),
        ),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final active = tabFor(location);
    const labels = {
      MobileTab.ping: 'PING',
      MobileTab.net: 'NET',
      MobileTab.tools: 'TOOLS',
      MobileTab.history: 'HISTORY',
    };
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: w.ink, width: kWireBorder),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final tab in MobileTab.values) ...[
              if (tab != MobileTab.ping) Container(width: kWireBorder, color: w.ink),
              Expanded(
                child: WireCell(
                  selected: tab == active,
                  onTap: () => context.go(kTabRoots[tab]!),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minHeight: WireLayout.minHit,
                  semanticLabel: labels[tab],
                  child: Text(labels[tab]!, style: WireType.label(11)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
