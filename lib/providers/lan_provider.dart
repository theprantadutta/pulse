import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/db/app_database.dart';
import '../data/models/session_tool.dart';
import '../services/net/lan/lan_scanner.dart';
import '../services/net/port_scanner.dart';
import 'database_provider.dart';
import 'network_provider.dart';
import 'ping_provider.dart';

/// A scanned device plus what Pulse remembers about it.
@immutable
class LanDevice {
  const LanDevice({required this.host, required this.type, this.firstSeen, this.isNew = false});
  final LanHost host;
  final DeviceType type;
  final DateTime? firstSeen;

  /// Never seen on this subnet before this scan.
  final bool isNew;

  String get displayName =>
      host.hostname ??
      (host.isGateway
          ? 'Router'
          : host.isSelf
          ? 'This device'
          : 'Unknown');
  String get key => host.mac ?? host.ip;
}

@immutable
class LanScanState {
  const LanScanState({
    this.cidr,
    this.localIp,
    this.prefix,
    this.broadcast,
    this.total = 0,
    this.probed = 0,
    this.devices = const [],
    this.phase = 'idle',
    this.current,
    this.startedAt,
    this.elapsed,
    this.error,
    this.selectedIp,
    this.ports = const {},
    this.scanningPorts = const {},
  });

  final String? cidr;
  final String? localIp;
  final int? prefix;
  final String? broadcast;
  final int total;
  final int probed;
  final List<LanDevice> devices;

  /// idle | probing | arp | names | done
  final String phase;
  final String? current;
  final DateTime? startedAt;
  final Duration? elapsed;
  final String? error;
  final String? selectedIp;

  /// Open ports found per device IP (detail panel).
  final Map<String, List<PortResult>> ports;
  final Set<String> scanningPorts;

  bool get running => phase != 'idle' && phase != 'done';

  LanDevice? get selected {
    for (final d in devices) {
      if (d.host.ip == selectedIp) return d;
    }
    return null;
  }

  LanScanState copyWith({
    String? cidr,
    String? localIp,
    int? prefix,
    String? broadcast,
    int? total,
    int? probed,
    List<LanDevice>? devices,
    String? phase,
    String? current,
    DateTime? startedAt,
    Duration? elapsed,
    String? error,
    String? selectedIp,
    Map<String, List<PortResult>>? ports,
    Set<String>? scanningPorts,
    bool clearError = false,
  }) => LanScanState(
    cidr: cidr ?? this.cidr,
    localIp: localIp ?? this.localIp,
    prefix: prefix ?? this.prefix,
    broadcast: broadcast ?? this.broadcast,
    total: total ?? this.total,
    probed: probed ?? this.probed,
    devices: devices ?? this.devices,
    phase: phase ?? this.phase,
    current: current ?? this.current,
    startedAt: startedAt ?? this.startedAt,
    elapsed: elapsed ?? this.elapsed,
    error: clearError ? null : error ?? this.error,
    selectedIp: selectedIp ?? this.selectedIp,
    ports: ports ?? this.ports,
    scanningPorts: scanningPorts ?? this.scanningPorts,
  );
}

final lanScannerProvider = Provider<LanScanner>((ref) => LanScanner(prober: ref.watch(pingProberProvider)));

final lanScanProvider = NotifierProvider<LanScanNotifier, LanScanState>(LanScanNotifier.new);

class LanScanNotifier extends Notifier<LanScanState> {
  StreamSubscription<LanScanProgress>? _sub;

  @override
  LanScanState build() {
    ref.onDispose(() => _sub?.cancel());
    return const LanScanState();
  }

  Future<void> scan() async {
    if (state.running) return;
    final snap = await ref.read(networkInfoProvider.future);
    final link = snap.link;
    if (link.localIpv4 == null) {
      state = state.copyWith(phase: 'done', error: 'Not connected to a local IPv4 network.');
      return;
    }
    final prefix = link.prefixLength ?? 24;
    final ip = link.localIpv4!;
    final cidr = LanScanner.cidrFor(ip, prefix);
    final db = ref.read(databaseProvider);
    final known = {
      for (final d in await (db.select(db.lanDevices)..where((t) => t.subnet.equals(cidr))).get()) d.key: d,
    };
    final started = DateTime.now();
    state = LanScanState(
      cidr: cidr,
      localIp: ip,
      prefix: prefix,
      broadcast: LanScanner.broadcastFor(ip, prefix),
      total: LanScanner.hostsFor(ip, prefix).length,
      phase: 'probing',
      startedAt: started,
      selectedIp: state.selectedIp,
      ports: state.ports,
    );

    List<LanDevice> devices(List<LanHost> hosts) => [
      for (final h in hosts)
        LanDevice(
          host: h,
          type: classifyDevice(h, openPorts: [for (final p in state.ports[h.ip] ?? const <PortResult>[]) p.port]),
          firstSeen: known[h.mac ?? h.ip]?.firstSeen,
          isNew: known.isNotEmpty && !known.containsKey(h.mac ?? h.ip) && !h.isSelf,
        ),
    ];

    final completer = Completer<void>();
    _sub?.cancel();
    _sub = ref
        .read(lanScannerProvider)
        .scan(localIp: ip, prefix: prefix, gateway: link.gateway)
        .listen(
          (p) {
            state = state.copyWith(
              probed: p.probed,
              total: p.total,
              devices: devices(p.hosts),
              phase: p.phase,
              current: p.current,
              elapsed: DateTime.now().difference(started),
            );
          },
          onError: (Object e) {
            state = state.copyWith(phase: 'done', error: '$e');
            completer.complete();
          },
          onDone: completer.complete,
        );
    await completer.future;
    await _persist(cidr, started);
  }

  Future<void> _persist(String cidr, DateTime started) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    await db.batch((b) {
      for (final d in state.devices) {
        b.insert(
          db.lanDevices,
          LanDevicesCompanion.insert(
            key: d.key,
            ip: d.host.ip,
            mac: Value(d.host.mac),
            hostname: Value(d.host.hostname),
            vendor: Value(d.host.vendor),
            subnet: cidr,
            firstSeen: d.firstSeen ?? now,
            lastSeen: now,
          ),
          onConflict: DoUpdate(
            (old) => LanDevicesCompanion(
              ip: Value(d.host.ip),
              hostname: Value(d.host.hostname),
              vendor: Value(d.host.vendor),
              lastSeen: Value(now),
            ),
          ),
        );
      }
    });
    final withFirstSeen = [
      for (final d in state.devices)
        LanDevice(host: d.host, type: d.type, isNew: d.isNew, firstSeen: d.firstSeen ?? now),
    ];
    state = state.copyWith(devices: withFirstSeen);
    final n = state.devices.length;
    final fresh = state.devices.where((d) => d.isNew).length;
    await ref
        .read(historyRepositoryProvider)
        .save(
          tool: SessionTool.lan,
          target: cidr,
          startedAt: started,
          endedAt: now,
          summary: '$n device${n == 1 ? '' : 's'}${fresh > 0 ? ' · $fresh new' : ''}',
          payload: {
            'devices': [
              for (final d in state.devices)
                {
                  'ip': d.host.ip,
                  'mac': d.host.mac,
                  'name': d.host.hostname,
                  'vendor': d.host.vendor,
                  'type': d.type.label,
                  'rtt': d.host.rttMs,
                  'new': d.isNew,
                },
            ],
          },
        );
  }

  void select(String ip) {
    state = state.copyWith(selectedIp: ip);
    if (!state.ports.containsKey(ip)) scanPorts(ip);
  }

  /// Quick COMMON-port scan for the detail panel.
  Future<void> scanPorts(String ip) async {
    if (state.scanningPorts.contains(ip)) return;
    state = state.copyWith(scanningPorts: {...state.scanningPorts, ip});
    final open = <PortResult>[];
    await for (final r in const PortScanner(
      timeout: Duration(milliseconds: 600),
    ).scan(InternetAddress(ip), kCommonPorts)) {
      if (r.state == PortState.open) open.add(r);
    }
    open.sort((a, b) => a.port.compareTo(b.port));
    final ports = {...state.ports, ip: open};
    state = state.copyWith(
      ports: ports,
      scanningPorts: {...state.scanningPorts}..remove(ip),
      devices: [
        for (final d in state.devices)
          d.host.ip == ip
              ? LanDevice(
                  host: d.host,
                  type: classifyDevice(d.host, openPorts: [for (final p in open) p.port]),
                  firstSeen: d.firstSeen,
                  isNew: d.isNew,
                )
              : d,
      ],
    );
  }
}
