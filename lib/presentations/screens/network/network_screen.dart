import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format.dart';
import '../../../core/widgets/pulse/pulse.dart';
import '../../../data/models/session_tool.dart';
import '../../../providers/connection_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/network_provider.dart';
import '../../../services/net/network_details.dart';
import '../../navigation/destinations.dart';
import '../lan/shape_wobble.dart';

/// 04 Network: the current link (pink hero card with the SSID), addressing and
/// internet details. Phone: hero + segmented details + "Scan network" FAB.
/// Tablet: hero, signal and link tiles and a LAN-scan card on the left, the
/// details list on the right.
class NetworkScreen extends ConsumerWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(networkInfoProvider);
    final snap = async.value;
    final refreshing = async.isLoading;
    final compact = context.isCompact;
    final online = snap != null && snap.link.kind != LinkKind.none;
    void refresh() => ref.read(networkInfoProvider.notifier).refresh();

    final Widget body;
    if (snap == null) {
      body = async.hasError
          ? ListView(
              padding: EdgeInsets.fromLTRB(context.pagePadding, 4, context.pagePadding, 24),
              children: [
                PulseErrorBanner(title: "Couldn't read the network", message: '${async.error}', onRetry: refresh),
              ],
            )
          : const _Reading();
    } else {
      body = LayoutBuilder(
        builder: (context, box) => !compact && online && box.maxWidth >= 880
            ? _WideBody(snap: snap)
            : _NarrowBody(snap: snap, fab: compact && online),
      );
    }

    return PulsePage(
      title: 'Network',
      large: true,
      subtitle: compact ? null : _updatedLabel(snap, refreshing),
      actions: [
        if (online) _CopyAllButton(text: snap.toText()),
        if (compact)
          PulseIconButton(
            icon: PulseIcons.refresh,
            tooltip: refreshing ? 'Refreshing…' : 'Refresh',
            style: PulseIconButtonStyle.neutral,
            visualSize: 48,
            onPressed: refreshing ? null : refresh,
          )
        else
          PulseButton(
            label: refreshing ? 'Refreshing…' : 'Refresh',
            icon: PulseIcons.refresh,
            style: PulseButtonStyle.tonal,
            onPressed: refreshing ? null : refresh,
          ),
      ],
      fab: compact && online
          ? PulseFab(label: 'Scan network', icon: PulseIcons.lan, onPressed: () => context.push(Routes.lan))
          : null,
      body: body,
    );
  }
}

String _updatedLabel(NetworkSnapshot? snap, bool refreshing) {
  if (snap == null) return 'Reading network interfaces…';
  if (refreshing) return 'Refreshing…';
  final age = DateTime.now().difference(snap.updatedAt);
  if (age.inSeconds < 30) return 'Updated just now';
  return 'Updated ${DateFormat('HH:mm:ss').format(snap.updatedAt)}';
}

class _Reading extends StatelessWidget {
  const _Reading();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 160, child: PulseWavyBar(value: .4, semanticLabel: 'Reading network interfaces')),
        const SizedBox(height: 12),
        Text(
          'Reading network interfaces…',
          style: context.type.bodyMedium!.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ],
    ),
  );
}

class _CopyAllButton extends StatelessWidget {
  const _CopyAllButton({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => PulseIconButton(
    icon: PulseIcons.copy,
    tooltip: 'Copy all details',
    onPressed: () {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Network details copied'), duration: Duration(seconds: 2)));
    },
  );
}

// ---------------------------------------------------------------------------
// Data shaping
// ---------------------------------------------------------------------------

/// "WI-FI 4" → "Wi-Fi 4", "2.4 GHZ" → "2.4 GHz".
String _nice(String s) => s.replaceAll('WI-FI', 'Wi-Fi').replaceAll('GHZ', 'GHz');

bool get _mobileOs => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

String get _osName => defaultTargetPlatform == TargetPlatform.iOS ? 'iOS' : 'Android';

/// Signal verdict (SCREENS.md §04): ≥ −60 Good, −60 to −70 Fair, < −70 Weak.
({String label, int bars}) _signal(int dbm) {
  if (dbm >= -60) return (label: 'Good', bars: 3);
  if (dbm >= -70) return (label: 'Fair', bars: 2);
  return (label: 'Weak', bars: 1);
}

String _dbm(int dbm) => dbm < 0 ? '−${dbm.abs()} dBm' : '$dbm dBm';

/// One row of the details list.
class _Detail {
  const _Detail(this.label, this.value, {this.copy = false, this.muted = false, this.privacy});
  final String label;
  final String value;
  final bool copy;

  /// Describes a missing value ("Not assigned", "Looking up…").
  final bool muted;

  /// Set for OS-hidden values: the "why" explanation behind the info button.
  final String? privacy;
}

_Detail _addr(String label, String? v, {String missing = '—'}) =>
    v == null || v.isEmpty ? _Detail(label, missing, muted: true) : _Detail(label, v, copy: true);

List<_Detail> _linkDetails(LinkDetails l) {
  final wifi = l.kind == LinkKind.wifi;
  return [
    _addr('Local IPv4', l.localIpv4),
    _addr('Subnet', l.subnetCidr),
    _addr('Gateway', l.gateway),
    _addr('DNS 1', l.dns.firstOrNull),
    _addr('DNS 2', l.dns.length > 1 ? l.dns[1] : null),
    if (l.mac != null)
      _Detail('MAC address', l.mac!, copy: true)
    else if (_mobileOs)
      _Detail(
        'MAC address',
        'Hidden by $_osName',
        muted: true,
        privacy:
            '$_osName does not let apps read the hardware (MAC) address of this device. '
            'Pulse shows it on Windows, macOS and Linux.',
      )
    else
      const _Detail('MAC address', '—', muted: true),
    _addr('IPv6', l.ipv6.firstOrNull, missing: 'Not assigned'),
    if (wifi && l.security != null) _Detail('Security', _nice(l.security!)),
    if (wifi && l.channel != null)
      _Detail('Channel', [l.channel.toString(), if (l.band != null) _nice(l.band!)].join(' · ')),
    if (!wifi && l.adapter != null) _Detail('Adapter', l.adapter!),
    _Detail('VPN', l.vpn ? ['On', ?l.vpnName].join(' · ') : 'Off', muted: !l.vpn),
  ];
}

List<_Detail> _internetDetails(NetworkSnapshot s) {
  _Detail pending(String label, String? v, {bool copy = true, String missing = 'Not available'}) {
    if (v != null && v.isNotEmpty) return _Detail(label, v, copy: copy);
    return _Detail(label, s.internetLoading ? 'Looking up…' : missing, muted: true);
  }

  String? ms(double? v) => v == null ? null : '${fmtMs(v)} ms';
  final g = s.geo;
  return [
    if (s.lookupsDisabled)
      const _Detail('Public IP', 'Off in Settings › Privacy', muted: true)
    else ...[
      pending('Public IP', g?.ip, missing: s.geoError == null ? 'Not available' : 'Lookup failed'),
      pending('ISP', g?.isp),
      pending('ASN', g?.asn == null ? null : [g!.asn, g.asName].whereType<String>().join(' · ')),
      pending('Location', g == null || g.place.isEmpty ? null : g.place),
    ],
    pending('Gateway ping', ms(s.gatewayPingMs), copy: false, missing: 'No reply'),
    pending('DNS ping', ms(s.dnsPingMs), copy: false, missing: 'No reply'),
    if (!s.lookupsDisabled) pending('Public IPv6', s.publicIpv6, missing: 'Not available'),
  ];
}

// ---------------------------------------------------------------------------
// Layouts
// ---------------------------------------------------------------------------

/// Phone (and narrow tablet / desktop window): one scrolling column.
class _NarrowBody extends StatelessWidget {
  const _NarrowBody({required this.snap, required this.fab});
  final NetworkSnapshot snap;
  final bool fab;

  @override
  Widget build(BuildContext context) {
    final l = snap.link;
    final pad = context.pagePadding;
    final offline = l.kind == LinkKind.none;
    final children = <Widget>[
      _HeroCard(link: l),
      if (l.ssidNeedsPermission) const _PermissionCard(),
      if (!offline) ...[
        if (!context.isCompact) const _ScanCard(),
        _DetailsList(details: _linkDetails(l)),
        _InternetHeader(snap: snap),
        _DetailsList(details: _internetDetails(snap)),
      ],
    ];
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 4, pad, fab ? PulseLayout.fabClearance + 16 : 24),
      children: [
        for (var i = 0; i < children.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 || children[i] is _InternetHeader ? 0 : PulseLayout.section),
            child: PulseEntrance(index: i, child: children[i]),
          ),
      ],
    );
  }
}

/// Tablet / desktop: hero, tiles and the scan card on the left; details right.
class _WideBody extends StatelessWidget {
  const _WideBody({required this.snap});
  final NetworkSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final l = snap.link;
    const pad = PulseLayout.tabletPadding;
    return LayoutBuilder(
      builder: (context, box) {
        final leftWidth = ((box.maxWidth - pad * 2 - 16) * .48).clamp(380.0, 540.0);
        final left = <Widget>[
          _HeroCard(link: l, tall: true),
          if (l.ssidNeedsPermission) const _PermissionCard(),
          _LinkTiles(link: l),
        ];
        final roomy = box.maxHeight >= 600;
        return Padding(
          padding: const EdgeInsets.fromLTRB(pad, 4, pad, pad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: leftWidth,
                child: roomy
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < left.length; i++) ...[
                            if (i > 0) const SizedBox(height: PulseLayout.section),
                            PulseEntrance(index: i, child: left[i]),
                          ],
                          const SizedBox(height: PulseLayout.section),
                          Expanded(
                            child: PulseEntrance(index: left.length, child: const _ScanCard(fill: true)),
                          ),
                        ],
                      )
                    : ListView(
                        children: [
                          for (final w in [...left, const _ScanCard()]) ...[
                            w,
                            const SizedBox(height: PulseLayout.section),
                          ],
                        ],
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ListView(
                  children: [
                    _DetailsList(details: _linkDetails(l), large: true),
                    _InternetHeader(snap: snap),
                    _DetailsList(details: _internetDetails(snap), large: true),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Hero card
// ---------------------------------------------------------------------------

/// Pink hero card (radius 32) with a spinning decorative cookie. Offline turns
/// it into an errorContainer card with "Open settings".
class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.link, this.tall = false});
  final LinkDetails link;
  final bool tall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = link;
    if (l.kind == LinkKind.none) return _OfflineHero(tall: tall);

    final on = c.onPrimaryFixed;
    final (PulseIcons icon, String kind, String title) = switch (l.kind) {
      LinkKind.wifi => (PulseIcons.wifi, 'Wi-Fi', l.ssidNeedsPermission ? 'Wi-Fi' : (l.ssid ?? l.name ?? 'Wi-Fi')),
      LinkKind.ethernet => (PulseIcons.lan, 'Ethernet', l.name ?? 'Ethernet'),
      LinkKind.cellular => (PulseIcons.signal, 'Mobile data', 'Mobile data'),
      LinkKind.vpn => (PulseIcons.shield, 'VPN', l.vpnName ?? l.name ?? 'VPN'),
      _ => (PulseIcons.globe, 'Network', l.name ?? 'Network'),
    };
    // Wi-Fi shows the generation and band; "Wi-Fi 4" already says Wi-Fi.
    final kindLine = l.kind == LinkKind.wifi
        ? [_nice(l.standard ?? 'Wi-Fi'), if (l.band != null) _nice(l.band!)].join(' · ')
        : kind;
    final dbm = l.kind == LinkKind.wifi ? l.signalDbm : null;
    final pills = <Widget>[
      if (dbm != null)
        _HeroPill(
          icon: PulseIcons.signal,
          label: tall ? '${_signal(dbm).label} signal' : '${_dbm(dbm)} · ${_signal(dbm).label}',
          inverse: true,
          large: tall,
        ),
      if (tall && l.kind == LinkKind.wifi && l.channel != null) _HeroPill(label: 'Channel ${l.channel}', large: tall),
      if (!(tall && l.kind == LinkKind.wifi) && l.linkMbps != null)
        _HeroPill(label: 'Link ${l.linkMbps} Mb/s', large: tall),
      if (l.vpn && l.kind != LinkKind.vpn) _HeroPill(icon: PulseIcons.shield, label: 'VPN on', large: tall),
    ];
    final cookie = tall ? 280.0 : 190.0;
    return Semantics(
      container: true,
      label: 'Connected, $kindLine, $title',
      child: Container(
        constraints: BoxConstraints(minHeight: tall ? 250 : 172),
        decoration: BoxDecoration(color: c.primaryFixedDim, borderRadius: BorderRadius.circular(32)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: tall ? -60 : -46,
              top: tall ? -70 : -40,
              child: ExcludeSemantics(
                child: PulseShapeBox(
                  shape: PulseShape.cookie12,
                  // Decorative cookie at 28% white (DESIGN_SYSTEM.md §6).
                  color: Colors.white.withValues(alpha: .28),
                  size: cookie,
                  spin: PulseMotion.heroSpin,
                ),
              ),
            ),
            Padding(
              padding: tall ? const EdgeInsets.fromLTRB(28, 24, 28, 24) : const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PulseIcon(icon, size: tall ? 20 : 18, color: on),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Connected · $kindLine',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: pulseText(tall ? 15 : 13, 700).copyWith(color: on),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tall ? 18 : 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: pulseText(tall ? 84 : 52, 900, wdth: 125, height: 1, tracking: -.03).copyWith(color: on),
                    ),
                  ),
                  if (pills.isNotEmpty) ...[
                    SizedBox(height: tall ? 22 : 16),
                    Wrap(spacing: 8, runSpacing: 8, children: pills),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill on the pink hero: inverse (onPink fill) or a 12% onPink tint.
class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, this.icon, this.inverse = false, this.large = false});
  final String label;
  final PulseIcons? icon;
  final bool inverse;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = inverse ? c.onPrimaryFixed : c.onPrimaryFixed.withValues(alpha: .12);
    final fg = inverse ? c.primaryFixedDim : c.onPrimaryFixed;
    final h = large ? 34.0 : 32.0;
    return Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: large ? 14 : 13),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(h / 2)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[PulseIcon(icon!, size: 16, color: fg), const SizedBox(width: 8)],
          Text(label, maxLines: 1, style: pulseText(large ? 15 : 14, 700, wdth: 105).copyWith(color: fg)),
        ],
      ),
    );
  }
}

class _OfflineHero extends ConsumerWidget {
  const _OfflineHero({required this.tall});
  final bool tall;

  Future<void> _openSettings() async {
    if (Platform.isWindows) {
      await launchUrl(Uri.parse('ms-settings:network'));
    } else if (Platform.isMacOS) {
      await launchUrl(Uri.parse('x-apple.systempreferences:com.apple.preference.network'));
    } else {
      await openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final on = c.onErrorContainer;
    // Linux has no single network-settings entry point to open.
    final canOpen = !kIsWeb && !Platform.isLinux;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        constraints: BoxConstraints(minHeight: tall ? 250 : 172),
        padding: tall ? const EdgeInsets.fromLTRB(28, 24, 28, 24) : const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(32)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PulseIcon(PulseIcons.wifi, size: 18, color: on),
                const SizedBox(width: 8),
                Text('Offline', style: pulseText(13, 700).copyWith(color: on)),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'No connection',
                maxLines: 1,
                style: pulseText(tall ? 64 : 44, 900, wdth: 125, height: 1, tracking: -.03).copyWith(color: on),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to Wi-Fi, mobile data or a cable, then refresh.',
              style: context.type.bodyMedium!.copyWith(color: on),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canOpen)
                  _SolidButton(
                    label: 'Open settings',
                    icon: PulseIcons.settings,
                    bg: on,
                    fg: c.errorContainer,
                    onTap: _openSettings,
                  ),
                _SolidButton(
                  label: 'Try again',
                  icon: PulseIcons.refresh,
                  bg: on.withValues(alpha: .12),
                  fg: on,
                  onTap: () => ref.read(networkInfoProvider.notifier).refresh(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A stadium button in explicit colours (on the error hero and the lime card).
class _SolidButton extends StatelessWidget {
  const _SolidButton({
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
    this.icon,
    this.large = false,
  });
  final String label;
  final PulseIcons? icon;
  final Color bg, fg;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final h = large ? 56.0 : 48.0;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PulsePressable(
        onTap: onTap,
        radius: h / 2,
        color: bg,
        child: Container(
          height: h,
          padding: EdgeInsets.symmetric(horizontal: large ? 24 : 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[PulseIcon(icon!, size: 18, color: fg), const SizedBox(width: 8)],
              Text(
                label,
                maxLines: 1,
                style: (large ? context.type.titleMedium : context.type.labelLarge)!.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Location permission (SSID)
// ---------------------------------------------------------------------------

class _PermissionCard extends ConsumerWidget {
  const _PermissionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    Future<void> grant() async {
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.locationWhenInUse.request();
        if (status.isPermanentlyDenied) await openAppSettings();
      } else if (Platform.isMacOS) {
        await launchUrl(Uri.parse('x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices'));
      }
      ref.read(networkInfoProvider.notifier).refresh();
    }

    final mac = !kIsWeb && Platform.isMacOS;
    return PulseCard(
      color: c.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          PulseIcon(PulseIcons.pin, size: 22, color: c.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wi-Fi name hidden', style: context.type.titleSmall),
                Text(
                  mac
                      ? 'macOS shows the network name only after Pulse gets Location Services access.'
                      : 'Allow location access so the system shares the network name.',
                  style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PulseButton(
            label: mac ? 'Open' : 'Allow',
            style: PulseButtonStyle.tonal,
            size: PulseButtonSize.small,
            onPressed: grant,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tablet tiles and the LAN-scan card
// ---------------------------------------------------------------------------

class _LinkTiles extends StatelessWidget {
  const _LinkTiles({required this.link});
  final LinkDetails link;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = link;
    final dbm = l.kind == LinkKind.wifi ? l.signalDbm : null;
    final valueStyle = pulseText(30, 900, wdth: 115, height: 1.1).copyWith(color: c.onSurface);

    final Widget first;
    if (l.kind == LinkKind.wifi) {
      final bars = dbm == null ? 0 : _signal(dbm).bars;
      final barColor = dbm == null
          ? c.surfaceContainerHighest
          : switch (bars) {
              3 => context.pulse.latFast,
              2 => context.pulse.latMedium,
              _ => context.pulse.latSlow,
            };
      first = _Tile(
        label: 'Signal',
        value: dbm == null ? '—' : _dbm(dbm),
        valueStyle: valueStyle,
        semantic: dbm == null ? 'Signal unknown' : 'Signal ${_dbm(dbm)}, ${_signal(dbm).label}',
        lead: _SignalBars(filled: bars, color: barColor),
      );
    } else {
      first = _Tile(
        label: 'Connection',
        value: switch (l.kind) {
          LinkKind.ethernet => 'Wired',
          LinkKind.cellular => 'Mobile',
          LinkKind.vpn => 'VPN',
          _ => 'Network',
        },
        valueStyle: valueStyle,
        lead: PulseShapeBadge(
          shape: PulseShape.clover4,
          tone: PulseTone.lime,
          icon: l.kind == LinkKind.cellular ? PulseIcons.signal : PulseIcons.lan,
          size: 48,
        ),
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: first),
          const SizedBox(width: 12),
          Expanded(
            child: _Tile(
              label: 'Link speed',
              value: l.linkMbps == null ? '—' : '${l.linkMbps} Mb/s',
              valueStyle: valueStyle,
              lead: const PulseShapeBadge(
                shape: PulseShape.sunny,
                tone: PulseTone.lavender,
                icon: PulseIcons.gauge,
                size: 48,
                spin: PulseMotion.heroSpin,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.valueStyle, required this.lead, this.semantic});
  final String label, value;
  final TextStyle valueStyle;
  final Widget lead;
  final String? semantic;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semantic ?? '$label $value',
    excludeSemantics: true,
    child: PulseCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      child: Row(
        children: [
          lead,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.type.labelMedium!.copyWith(color: context.colors.onSurfaceVariant)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, maxLines: 1, style: valueStyle),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Four rising signal bars; [filled] of them in [color].
class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.filled, required this.color});
  final int filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final reduce = PulseMotion.reduced(context);
    const heights = [14.0, 24.0, 34.0, 44.0];
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: reduce ? 1 : 0, end: 1),
              duration: PulseMotion.barGrow + Duration(milliseconds: 60 * i),
              curve: PulseMotion.spring,
              builder: (context, t, _) => Container(
                width: 10,
                height: (heights[i] * t).clamp(0, 44).toDouble(),
                decoration: BoxDecoration(
                  color: i < filled ? color : context.colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lime "Who's on this network?" card with the last LAN scan and a Scan button.
class _ScanCard extends ConsumerWidget {
  const _ScanCard({this.fill = false});

  /// Fill the remaining column height (tablet).
  final bool fill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(latestSessionsProvider).value?[SessionTool.lan];
    final line = last == null || last.summary.isEmpty
        ? 'See every device on your network'
        : 'Last scan found ${last.summary} · ${DateFormat('MMM d, HH:mm').format(last.startedAt)}';
    final content = Row(
      children: [
        SizedBox.square(
          dimension: 64,
          child: ExcludeSemantics(
            child: Stack(
              alignment: Alignment.center,
              children: [
                const ShapeWobble(
                  child: PulseShapeBox(shape: PulseShape.clover4, color: PulseBrand.onLime, size: 64),
                ),
                const PulseIcon(PulseIcons.lan, size: 28, color: PulseBrand.lime),
              ],
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Who's on this network?",
                style: pulseText(20, 800, wdth: 105, height: 1.2).copyWith(color: PulseBrand.onLime),
              ),
              const SizedBox(height: 2),
              Text(line, style: context.type.bodyMedium!.copyWith(color: PulseBrand.onLime)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _SolidButton(
          label: 'Scan network',
          bg: PulseBrand.onLime,
          fg: PulseBrand.lime,
          large: true,
          onTap: () => context.push(Routes.lan),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      alignment: fill ? Alignment.center : null,
      decoration: BoxDecoration(color: PulseBrand.lime, borderRadius: BorderRadius.circular(28)),
      child: content,
    );
  }
}

// ---------------------------------------------------------------------------
// Details list
// ---------------------------------------------------------------------------

class _InternetHeader extends StatelessWidget {
  const _InternetHeader({required this.snap});
  final NetworkSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final source = snap.geo?.source;
    return PulseSectionLabel(
      'Internet',
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      trailing: snap.internetLoading
          ? Text('Checking…', style: context.type.bodySmall!.copyWith(color: context.colors.onSurfaceVariant))
          : source == null
          ? null
          : Text('via $source', style: context.type.bodySmall!.copyWith(color: context.colors.onSurfaceVariant)),
    );
  }
}

/// Segmented list of label / value rows with copy or info buttons.
class _DetailsList extends StatelessWidget {
  const _DetailsList({required this.details, this.large = false});
  final List<_Detail> details;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = details.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) const SizedBox(height: PulseLayout.seam),
          _DetailTile(detail: details[i], radius: segmentedRadius(i, n), large: large, color: c.surfaceContainer),
        ],
      ],
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.detail, required this.radius, required this.large, required this.color});
  final _Detail detail;
  final BorderRadius radius;
  final bool large;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = detail;
    final valueStyle = large
        ? pulseText(20, d.muted ? 500 : 600, height: 1.25)
        : pulseText(16, d.muted ? 500 : 600, height: 1.3);
    final Widget? trailing = d.copy
        ? PulseCopyButton(text: d.value, label: 'Copy ${d.label}')
        : d.privacy != null
        ? PulsePrivacyNote(explanation: d.privacy!)
        : null;
    return MergeSemantics(
      child: Container(
        constraints: BoxConstraints(minHeight: large ? 76 : 56),
        padding: EdgeInsets.fromLTRB(large ? 20 : 16, large ? 6 : 2, 4, large ? 6 : 2),
        decoration: BoxDecoration(color: color, borderRadius: radius),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.label,
                    style: context.type.bodySmall!.copyWith(fontSize: large ? 13 : 12, color: c.onSurfaceVariant),
                  ),
                  Text(
                    d.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle.copyWith(color: d.muted ? c.onSurfaceVariant : c.onSurface),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing else const SizedBox(width: 12, height: 48),
          ],
        ),
      ),
    );
  }
}
