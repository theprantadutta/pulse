import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format.dart';
import '../../../core/widgets/wire/wire.dart';
import '../../../core/widgets/wire/wire_page.dart';
import '../../../providers/connection_provider.dart';
import '../../../providers/network_provider.dart';
import '../../../services/net/network_details.dart';
import '../../navigation/destinations.dart';

/// 04 — Network info.
class NetworkScreen extends ConsumerWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(networkInfoProvider);
    final snap = async.value;
    final refreshing = async.isLoading;
    void refresh() => ref.read(networkInfoProvider.notifier).refresh();

    Widget body(bool mobile) {
      if (snap == null) {
        if (async.hasError) {
          return WireErrorBlock(title: 'NO DATA', reason: '${async.error}', onRetry: refresh);
        }
        return Center(child: Text('Reading network interfaces…', style: WireType.body(13)));
      }
      if (snap.link.kind == LinkKind.none) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WireErrorBlock(
              title: 'OFFLINE',
              reason: 'No network connection. Connect to Wi-Fi or a cable and refresh.',
              size: mobile ? 72 : 120,
              onRetry: refresh,
            ),
          ],
        );
      }
      return mobile ? _MobileBody(snap: snap) : _DesktopBody(snap: snap);
    }

    return WireAdaptive(
      mobile: (context) => WireMobilePage(
        header: WireMobileHeader(
          title: 'Network',
          trailing: _HeaderLink(label: refreshing ? 'READING…' : '↻ REFRESH', onTap: refresh),
        ),
        body: body(true),
        action: WireButton.bar(
          label: 'LAN scan →',
          variant: WireButtonVariant.inverse,
          onPressed: () => context.push(Routes.lan),
        ),
      ),
      desktop: (context) => WireDesktopPage(
        topBar: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: WireTopTitle(
                'Network',
                subtitle: snap == null
                    ? 'READING…'
                    : 'UPDATED ${DateFormat('HH:mm:ss').format(snap.updatedAt)}${refreshing ? ' · REFRESHING' : ''}',
              ),
            ),
            const WireVRule(),
            if (snap != null) _CopyAllCell(text: snap.toText()),
            WireButton(
              label: 'Refresh',
              glyph: '↻',
              variant: WireButtonVariant.inverse,
              bordered: false,
              fontSize: 17,
              height: WireLayout.topBar,
              busy: refreshing,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              onPressed: refresh,
            ),
          ],
        ),
        body: body(false),
      ),
    );
  }
}

class _HeaderLink extends StatelessWidget {
  const _HeaderLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return WirePressable(
      onTap: onTap,
      tone: WireTone.ink,
      semanticLabel: label,
      builder: (context, c, s) => Container(
        color: c.bg,
        height: WireLayout.mobileHeader,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(label, style: WireType.label(12).copyWith(color: s.isEmpty ? w.signal : c.fg)),
      ),
    );
  }
}

class _CopyAllCell extends StatefulWidget {
  const _CopyAllCell({required this.text});
  final String text;

  @override
  State<_CopyAllCell> createState() => _CopyAllCellState();
}

class _CopyAllCellState extends State<_CopyAllCell> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return WireCell(
      selected: _copied,
      sides: WireSides.onlyRight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: widget.text));
        setState(() => _copied = true);
        await Future<void>.delayed(WireMotion.copied);
        if (mounted) setState(() => _copied = false);
      },
      child: Text(_copied ? 'COPIED' : 'COPY ALL', style: WireType.data(13)),
    );
  }
}

String _kindLabel(LinkDetails l) => switch (l.kind) {
  LinkKind.wifi => 'WI-FI',
  LinkKind.ethernet => 'ETHERNET',
  LinkKind.cellular => 'CELLULAR',
  LinkKind.vpn => 'VPN',
  LinkKind.other => 'NETWORK',
  LinkKind.none => 'OFFLINE',
};

List<(String, String?)> _addressing(LinkDetails l) => [
  ('Local IPv4', l.localIpv4),
  ('Subnet', l.subnetCidr),
  ('Gateway', l.gateway),
  ('DNS 1', l.dns.firstOrNull),
  ('DNS 2', l.dns.length > 1 ? l.dns[1] : null),
  ('MAC', l.mac ?? (Platform.isAndroid || Platform.isIOS ? 'hidden by the OS' : null)),
  ('IPv6', l.ipv6.firstOrNull),
];

List<(String, String?)> _internet(NetworkSnapshot s) {
  String? pending(String? v) => v ?? (s.internetLoading ? '…' : null);
  if (s.lookupsDisabled) {
    return [
      ('Public IP', 'lookups off in Settings'),
      ('GW ping', pending(s.gatewayPingMs == null ? null : '${fmtMs(s.gatewayPingMs)} ms')),
      ('DNS ping', pending(s.dnsPingMs == null ? null : '${fmtMs(s.dnsPingMs)} ms')),
    ];
  }
  final g = s.geo;
  return [
    ('Public IP', pending(g?.ip) ?? (s.geoError == null ? null : 'lookup failed')),
    ('ISP', pending(g?.isp)),
    ('ASN', pending(g?.asn == null ? null : [g!.asn, g.asName].whereType<String>().join(' · '))),
    ('Location', pending(g?.place.isEmpty ?? true ? null : g!.place)),
    ('GW ping', pending(s.gatewayPingMs == null ? null : '${fmtMs(s.gatewayPingMs)} ms')),
    ('DNS ping', pending(s.dnsPingMs == null ? null : '${fmtMs(s.dnsPingMs)} ms')),
    ('IPv6 net', s.publicIpv6 ?? (s.internetLoading ? '…' : 'not available')),
  ];
}

/// Placeholder phrases that describe a missing value rather than hold one.
const _notes = {'…', 'not available', 'lookup failed', 'lookups off in Settings', 'hidden by the OS'};

bool _copyable(String? v) => v != null && !_notes.contains(v);

List<String> _chips(LinkDetails l) => [
  if (l.kind == LinkKind.wifi) ...[?l.standard, ?l.band, if (l.channel != null) 'CH ${l.channel}', ?l.security],
  if (l.kind == LinkKind.ethernet && l.adapter != null) 'WIRED',
];

class _PermissionPrompt extends ConsumerWidget {
  const _PermissionPrompt({this.dense = false});
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    Future<void> grant() async {
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.locationWhenInUse.request();
        if (status.isPermanentlyDenied) await openAppSettings();
      } else if (Platform.isMacOS) {
        await launchUrl(Uri.parse('x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices'));
      }
      ref.read(networkInfoProvider.notifier).refresh();
    }

    return WireRow(
      onTap: grant,
      highlight: WireRowHighlight.tint,
      padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              Platform.isMacOS
                  ? 'macOS hides the Wi-Fi name until Pulse has Location Services access.'
                  : 'Allow location access to show the Wi-Fi name.',
              style: WireType.body(12).copyWith(color: w.ink),
            ),
          ),
          const SizedBox(width: 10),
          Text('ALLOW →', style: WireType.label(12)),
        ],
      ),
    );
  }
}

class _DesktopBody extends StatelessWidget {
  const _DesktopBody({required this.snap});
  final NetworkSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final l = snap.link;
    final chips = _chips(l);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: w.ink, width: kWireBorder))),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('● CONNECTED · ${_kindLabel(l)}', style: WireType.label(12)),
                        const SizedBox(height: 10),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            (l.name ?? _kindLabel(l)).toUpperCase(),
                            maxLines: 1,
                            style: WireType.display(120).copyWith(color: w.ink),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ChipStrip(chips: chips, vpn: l.vpn, vpnName: l.vpnName),
                      ],
                    ),
                  ),
                ),
                const WireVRule(),
                SizedBox(
                  width: 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: w.ink, width: kWireBorder))),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: _BigStat(
                                  label: 'Signal',
                                  value: l.kind == LinkKind.wifi
                                      ? (l.signalDbm == null ? '—' : '−${l.signalDbm!.abs()} DBM')
                                      : 'WIRED',
                                ),
                              ),
                              if (l.kind == LinkKind.wifi) WireBlockMeter(filled: l.signalBars, blockWidth: 12, maxHeight: 44),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          child: _BigStat(
                            label: 'Link speed',
                            value: l.linkMbps == null ? '—' : '${l.linkMbps} MBPS',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (l.ssidNeedsPermission) const _PermissionPrompt(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _Table(title: 'Addressing', rows: _addressing(l))),
              const WireVRule(),
              Expanded(
                child: _Table(
                  title: 'Internet',
                  rows: _internet(snap),
                  footer: snap.geo == null ? null : 'via ${snap.geo!.source}',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(label.toUpperCase(), style: WireType.label()),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: WireType.stat(44).copyWith(color: context.wire.ink)),
        ),
      ],
    );
  }
}

class _ChipStrip extends StatelessWidget {
  const _ChipStrip({required this.chips, required this.vpn, this.vpnName});
  final List<String> chips;
  final bool vpn;
  final String? vpnName;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final all = [...chips, vpn ? 'VPN ON' : 'VPN OFF'];
    return Container(
      decoration: BoxDecoration(border: Border.all(color: w.ink, width: kWireBorder)),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < all.length; i++) ...[
              if (i > 0) const WireVRule(),
              Tooltip(
                message: i == all.length - 1 && vpn && vpnName != null ? vpnName! : '',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: i == all.length - 1 ? w.ink : null,
                  child: Text(
                    all[i],
                    style: WireType.label(12).copyWith(color: i == all.length - 1 ? w.background : w.ink),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.title, required this.rows, this.footer});
  final String title;
  final List<(String, String?)> rows;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WireSectionBar(title, trailing: footer == null ? null : Text(footer!.toUpperCase())),
        Expanded(
          child: ListView(
            children: [
              for (final (k, v) in rows)
                WireKeyValueRow(
                  label: k,
                  value: v ?? '—',
                  copy: _copyable(v),
                  valueColor: _copyable(v) ? null : w.text3,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileBody extends StatelessWidget {
  const _MobileBody({required this.snap});
  final NetworkSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final l = snap.link;
    final meta = ['● CONNECTED', _kindLabel(l), ?l.standard, ?l.band].join(' · ');
    final rows = [..._addressing(l), ..._internet(snap)];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: w.signal,
            border: Border(bottom: BorderSide(color: w.ink, width: kWireBorder)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meta, style: WireType.label().copyWith(color: w.onSignal)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  (l.name ?? _kindLabel(l)).toUpperCase(),
                  maxLines: 1,
                  style: WireType.display(76).copyWith(color: w.onSignal),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: w.ink, width: kWireBorder))),
          child: WireSplitRow(
            children: [
              WireStat(
                label: 'Signal',
                value: l.kind == LinkKind.wifi ? (l.signalDbm == null ? '—' : '−${l.signalDbm!.abs()} DBM') : 'WIRED',
                valueSize: 30,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              ),
              WireStat(
                label: 'Link',
                value: l.linkMbps == null ? '—' : '${l.linkMbps} MB/S',
                valueSize: 30,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              ),
            ],
          ),
        ),
        if (l.ssidNeedsPermission) const _PermissionPrompt(dense: true),
        for (final (k, v) in rows)
          WireRow(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k.toUpperCase(), style: WireType.label(10).copyWith(color: w.text2)),
                      Text(
                        v ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WireType.data(14).copyWith(color: _copyable(v) ? w.ink : w.text3),
                      ),
                    ],
                  ),
                ),
                if (_copyable(v)) WireCopyButton(value: () => v!, fontSize: 10, height: 28),
              ],
            ),
          ),
      ],
    );
  }
}
