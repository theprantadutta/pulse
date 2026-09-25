import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/wire/wire.dart';
import '../../../core/widgets/wire/wire_page.dart';
import '../../../providers/lan_provider.dart';
import '../../../providers/ping_provider.dart';
import '../../../services/net/lan/arp_table.dart';
import '../../../services/net/lan/lan_scanner.dart';
import '../../../services/net/lan/name_probe.dart';
import '../../navigation/destinations.dart';

/// 05 — LAN scan.
class LanScreen extends ConsumerStatefulWidget {
  const LanScreen({super.key});

  @override
  ConsumerState<LanScreen> createState() => _LanScreenState();
}

class _LanScreenState extends ConsumerState<LanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(lanScanProvider);
      if (s.phase == 'idle') ref.read(lanScanProvider.notifier).scan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(lanScanProvider);
    final notifier = ref.read(lanScanProvider.notifier);
    final method = ArpTable.available ? 'ARP + ICMP' : 'ICMP + TCP';
    return WireAdaptive(
      mobile: (context) => WireMobilePage(
        header: WireMobileHeader(
          title: 'LAN scan',
          onBack: GoRouter.maybeOf(context)?.canPop() == true ? () => context.pop() : null,
          trailing: Text(
            s.running ? 'SCANNING' : 'DONE',
            style: WireType.label(12).copyWith(color: context.wire.signal),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MobileSummary(state: s),
            Expanded(child: _MobileList(state: s)),
          ],
        ),
        action: WireButton.bar(
          label: s.running ? 'Scanning…' : 'Scan again',
          glyph: '↻',
          busy: s.running,
          variant: WireButtonVariant.inverse,
          onPressed: s.running ? null : notifier.scan,
        ),
      ),
      desktop: (context) => WireDesktopPage(
        topBar: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('SUBNET>', style: WireType.label(12)),
                    const SizedBox(width: 16),
                    Text(s.cidr ?? '—', style: WireType.data(20)),
                    const SizedBox(width: 16),
                    Text('${s.total} hosts', style: WireType.body(13).copyWith(color: context.wire.text3)),
                  ],
                ),
              ),
            ),
            const WireVRule(),
            WireTopChip(label: method),
            WireButton(
              label: 'Scan again',
              glyph: '↻',
              variant: WireButtonVariant.inverse,
              bordered: false,
              busy: s.running,
              fontSize: 17,
              height: WireLayout.topBar,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              onPressed: s.running ? null : notifier.scan,
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DesktopSummary(state: s),
            Expanded(child: _DeviceTable(state: s)),
          ],
        ),
        panel: _DetailPanel(state: s),
      ),
    );
  }
}

String _progressLine(LanScanState s) {
  if (s.error != null) return s.error!;
  return switch (s.phase) {
    'probing' => 'PROBING · ${s.probed} / ${s.total}',
    'arp' => 'READING ARP TABLE · ${s.total} / ${s.total}',
    'names' => 'RESOLVING NAMES & VENDORS',
    'done' => 'SCAN COMPLETE · ${s.total} / ${s.total}',
    _ => 'READY',
  };
}

double? _progress(LanScanState s) {
  if (s.phase == 'idle') return 0;
  if (s.phase == 'probing') return s.total == 0 ? null : s.probed / s.total;
  if (s.phase == 'done') return 1;
  return null;
}

class _DesktopSummary extends StatelessWidget {
  const _DesktopSummary({required this.state});
  final LanScanState state;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final s = state;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: w.ink, width: kWireBorder))),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
              decoration: BoxDecoration(border: Border(right: BorderSide(color: w.ink, width: kWireBorder))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${s.devices.length}', style: WireType.hero(96)),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('DEVICES\nFOUND', style: WireType.stat(28).copyWith(height: 0.95)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _progressLine(s),
                            style: WireType.label(12).copyWith(color: s.error != null ? w.signal : w.ink),
                          ),
                        ),
                        Text(
                          s.elapsed == null ? '' : '${(s.elapsed!.inMilliseconds / 1000).toStringAsFixed(1)} S',
                          style: WireType.label(12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    WireProgress(value: _progress(s), height: 18, signal: s.running),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTable extends ConsumerWidget {
  const _DeviceTable({required this.state});
  final LanScanState state;

  static const cols = [
    WireCol('IP', width: 130),
    WireCol('Device', flex: 3),
    WireCol('Vendor', flex: 2),
    WireCol('Type', width: 80),
    WireCol('RTT', width: 60),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final s = state;
    if (s.devices.isEmpty && !s.running) {
      return WireEmptyState(
        title: 'No devices',
        message: s.error ?? 'Nothing answered on ${s.cidr ?? 'this network'}.',
        actionLabel: 'Scan',
        actionGlyph: '↻',
        onAction: ref.read(lanScanProvider.notifier).scan,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WireTableHeader(columns: cols, gap: 10),
        Expanded(
          child: ListView.builder(
            itemCount: s.devices.length,
            itemBuilder: (context, i) {
              final d = s.devices[i];
              final tag = d.host.isGateway
                  ? 'GATEWAY'
                  : d.host.isSelf
                  ? 'THIS DEVICE'
                  : d.isNew
                  ? 'NEW'
                  : null;
              return WireRow(
                selected: d.host.ip == s.selectedIp,
                highlight: d.host.isSelf ? WireRowHighlight.muted : WireRowHighlight.none,
                onTap: () => ref.read(lanScanProvider.notifier).select(d.host.ip),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: WireColumns(
                  columns: cols,
                  gap: 10,
                  cells: [
                    Text(d.host.ip, style: WireType.data(13)),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: d.displayName, style: WireType.data(13)),
                          if (tag != null)
                            TextSpan(
                              text: '  $tag',
                              style: WireType.body(12).copyWith(color: tag == 'NEW' ? w.signal : w.text2),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(d.host.vendor ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: WireType.body(13).copyWith(height: 1.2)),
                    Text(d.type.label, style: WireType.body(13).copyWith(height: 1.2)),
                    Text(d.host.rttMs == null ? 'ARP' : fmtMs(d.host.rttMs), style: WireType.data(13)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DetailPanel extends ConsumerWidget {
  const _DetailPanel({required this.state});
  final LanScanState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final d = state.selected;
    if (d == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Select a device to see its details.', style: WireType.body(13).copyWith(color: w.text3)),
        ),
      );
    }
    final ports = state.ports[d.host.ip];
    final scanning = state.scanningPorts.contains(d.host.ip);
    final rows = <(String, String)>[
      ('Hostname', d.host.hostname ?? '—'),
      ('MAC', d.host.mac ?? (ArpTable.available ? '—' : 'hidden by the OS')),
      ('Vendor', d.host.vendor ?? '—'),
      ('Open ports', scanning ? 'scanning…' : (ports == null || ports.isEmpty) ? 'none of the common ports' : ports.map((p) => p.port).join(' · ')),
      ('First seen', d.firstSeen == null ? 'this scan' : DateFormat('MMM d, HH:mm').format(d.firstSeen!)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: w.signalTint,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SELECTED · ${d.displayName.toUpperCase()}', style: WireType.label()),
              const SizedBox(height: 4),
              Text(d.host.ip, style: WireType.stat(36)),
            ],
          ),
        ),
        const WireRule(),
        Expanded(
          child: ListView(
            children: [
              for (final (k, v) in rows)
                WireRow(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k.toUpperCase(), style: WireType.label(10).copyWith(color: w.text2)),
                      SelectableText(v, style: WireType.data(14)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        _DeviceActions(device: d, broadcast: state.broadcast),
      ],
    );
  }
}

class _DeviceActions extends ConsumerWidget {
  const _DeviceActions({required this.device, required this.broadcast});
  final LanDevice device;
  final String? broadcast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final d = device;
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: w.ink, width: kWireBorder))),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: WireButton(
                label: 'Ping',
                variant: WireButtonVariant.primary,
                bordered: false,
                sides: WireSides.onlyRight,
                fontSize: 16,
                height: 52,
                onPressed: () async {
                  await ref.read(pingBoardProvider.notifier).start(
                    d.host.ip,
                    name: d.host.hostname ?? (d.host.isGateway ? 'Router' : null),
                  );
                  if (context.mounted) context.go(Routes.ping);
                },
              ),
            ),
            Expanded(
              child: WireButton(
                label: 'Ports',
                bordered: false,
                sides: WireSides.onlyRight,
                fontSize: 16,
                height: 52,
                onPressed: () => context.go('${Routes.ports}?target=${d.host.ip}'),
              ),
            ),
            Expanded(
              child: WireButton(
                label: 'Wake',
                bordered: false,
                fontSize: 16,
                height: 52,
                tooltip: d.host.mac == null ? 'Needs the device MAC address' : 'Send a Wake-on-LAN magic packet',
                onPressed: d.host.mac == null
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await WakeOnLan.wake(d.host.mac!, broadcasts: [?broadcast, '255.255.255.255']);
                          messenger.showSnackBar(SnackBar(content: Text('Magic packet sent to ${d.host.mac}')));
                        } on Object catch (e) {
                          messenger.showSnackBar(SnackBar(content: Text('Wake failed: $e')));
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileSummary extends StatelessWidget {
  const _MobileSummary({required this.state});
  final LanScanState state;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final s = state;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: w.ink, width: kWireBorder))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${s.devices.length} ', style: WireType.hero(60)),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('DEVICES', style: WireType.title(22)),
              ),
              const Spacer(),
              Text(s.phase == 'probing' ? '${s.probed} / ${s.total}' : s.phase.toUpperCase(), style: WireType.label(12)),
            ],
          ),
          const SizedBox(height: 8),
          WireProgress(value: _progress(s), signal: s.running),
          const SizedBox(height: 8),
          Text(
            s.error ?? '${s.cidr ?? ''}${s.phase == 'probing' && s.current != null ? ' · probing .${s.current!.split('.').last}' : ''}',
            style: WireType.body(11).copyWith(color: s.error != null ? w.signal : w.text2),
          ),
        ],
      ),
    );
  }
}

class _MobileList extends ConsumerWidget {
  const _MobileList({required this.state});
  final LanScanState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    return ListView.builder(
      itemCount: state.devices.length,
      itemBuilder: (context, i) {
        final d = state.devices[i];
        return WireRow(
          highlight: d.host.isSelf ? WireRowHighlight.muted : d.isNew ? WireRowHighlight.tint : WireRowHighlight.none,
          onTap: () {
            ref.read(lanScanProvider.notifier).select(d.host.ip);
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (context) => ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
                child: Consumer(builder: (context, ref, _) => _DetailPanel(state: ref.watch(lanScanProvider))),
              ),
            );
          },
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${d.displayName}${d.host.isGateway ? ' · GATEWAY' : d.isNew ? ' · NEW' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WireType.data(14),
                    ),
                    Text(
                      '${d.host.ip} · ${d.host.vendor ?? d.type.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WireType.body(11).copyWith(color: w.text2, height: 1.3),
                    ),
                  ],
                ),
              ),
              Text(d.host.rttMs == null ? 'ARP' : fmtMs(d.host.rttMs), style: WireType.stat(22)),
            ],
          ),
        );
      },
    );
  }
}
