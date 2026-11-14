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
  const LanDevice({
    required this.host,
    required this.type,
    this.firstSeen,
    this.isNew = false,
    this.customName,
    this.customType,
  });
  final LanHost host;
  final DeviceType type;
  final DateTime? firstSeen;

  /// Never seen on this subnet before this scan.
  final bool isNew;

  /// The name the user gave it (Edit device).
  final String? customName;

  /// The type the user picked (Edit device), over the detected [type].
  final DeviceType? customType;

  /// What the device is: the user's pick, else what the scan detected.
  DeviceType get kind => customType ?? type;

  /// The user's name, then the name the device announces, its network name,
  /// its model, then its role.
  String get displayName =>
      customName ??
      host.friendlyName ??
      host.hostname ??
      host.model ??
      (host.isGateway
          ? 'Router'
          : host.isSelf
          ? 'This device'
          : host.vendor != null
          ? '${_shortVendor(host.vendor!)} device'
          : 'Unknown device');

  /// Nothing at all is known about it.
  bool get isUnknown =>
      customName == null &&
      customType == null &&
      host.friendlyName == null &&
      host.hostname == null &&
      host.model == null &&
      host.vendor == null &&
      !host.isGateway &&
      !host.isSelf;

  String get key => host.mac ?? host.ip;

  LanDevice copyWith({
    DeviceType? type,
    String? customName,
    bool clearCustomName = false,
    DeviceType? customType,
    bool clearCustomType = false,
    DateTime? firstSeen,
  }) => LanDevice(
    host: host,
    type: type ?? this.type,
    isNew: isNew,
    firstSeen: firstSeen ?? this.firstSeen,
    customName: clearCustomName ? null : customName ?? this.customName,
    customType: clearCustomType ? null : customType ?? this.customType,
  );

  static DeviceType? typeFromName(String? name) {
    for (final t in DeviceType.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  // "Samsung Electronics Co.,Ltd" -> "Samsung".
  static String _shortVendor(String v) => v.split(RegExp(r'[ ,]')).first;
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

  /// Bumped when a sweep starts, so a port check that overlapped one is dropped.
  int _sweep = 0;

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
    final rows = await (db.select(db.lanDevices)..where((t) => t.subnet.equals(cidr))).get();
    final known = {for (final d in rows) d.key: d};
    // A renamed device keeps its name when DHCP moves it to another address.
    final byIdentity = {
      for (final d in rows)
        if (d.identity != null && (d.customName != null || d.pickedType != null)) d.identity!: d,
    };
    final started = DateTime.now();
    _sweep++;
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
          customName: known[h.mac ?? h.ip]?.customName ?? byIdentity[h.identity]?.customName,
          customType: LanDevice.typeFromName(known[h.mac ?? h.ip]?.pickedType ?? byIdentity[h.identity]?.pickedType),
        ),
    ];

    final completer = Completer<void>();
    _sub?.cancel();
    _sub = ref
        .read(lanScannerProvider)
        .scan(localIp: ip, prefix: prefix, gateway: link.gateway, dnsServers: link.dns)
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
    // The selected device's quick port check waits for the sweep (see scanPorts).
    // Re-checked every sweep, so an old result never sticks.
    final selected = state.selectedIp;
    if (selected != null) unawaited(scanPorts(selected));
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
            model: Value(d.host.model),
            identity: Value(d.host.identity),
            customName: Value(d.customName),
            pickedType: Value(d.customType?.name),
            subnet: cidr,
            firstSeen: d.firstSeen ?? now,
            lastSeen: now,
          ),
          onConflict: DoUpdate(
            (old) => LanDevicesCompanion(
              ip: Value(d.host.ip),
              hostname: Value(d.host.hostname),
              vendor: Value(d.host.vendor),
              model: Value(d.host.model),
              identity: Value(d.host.identity),
              // Never clear a name the user chose; carry one found by identity.
              customName: d.customName == null ? const Value.absent() : Value(d.customName),
              pickedType: d.customType == null ? const Value.absent() : Value(d.customType!.name),
              lastSeen: Value(now),
            ),
          ),
        );
      }
    });
    final withFirstSeen = [for (final d in state.devices) d.copyWith(firstSeen: d.firstSeen ?? now)];
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
                  'name': d.displayName,
                  'hostname': d.host.hostname,
                  'model': d.host.model,
                  'vendor': d.host.vendor,
                  'services': d.host.services,
                  'type': d.kind.label,
                  'rtt': d.host.rttMs,
                  'new': d.isNew,
                },
            ],
          },
        );
  }

  /// Saves the user's name and type for [device]; an empty [name] or a null
  /// [type] goes back to what the scan found. Saved per device (MAC, else IP)
  /// and remembered by identity, so it survives the router handing out a new
  /// address.
  Future<void> edit(LanDevice device, {String? name, DeviceType? type}) async {
    final value = name?.trim();
    final custom = value == null || value.isEmpty ? null : value;
    final kind = type == device.type ? null : type;
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    await db
        .into(db.lanDevices)
        .insert(
          LanDevicesCompanion.insert(
            key: device.key,
            ip: device.host.ip,
            mac: Value(device.host.mac),
            hostname: Value(device.host.hostname),
            vendor: Value(device.host.vendor),
            model: Value(device.host.model),
            identity: Value(device.host.identity),
            customName: Value(custom),
            pickedType: Value(kind?.name),
            subnet: state.cidr ?? '',
            firstSeen: device.firstSeen ?? now,
            lastSeen: now,
          ),
          onConflict: DoUpdate((old) => LanDevicesCompanion(customName: Value(custom), pickedType: Value(kind?.name))),
        );
    // Clearing clears rows that share this identity too, so identity matching
    // can't bring an old name or type back.
    if ((custom == null || kind == null) && device.host.identity != null) {
      await (db.update(db.lanDevices)..where((t) => t.identity.equals(device.host.identity!))).write(
        LanDevicesCompanion(
          customName: custom == null ? const Value(null) : const Value.absent(),
          pickedType: kind == null ? const Value(null) : const Value.absent(),
        ),
      );
    }
    state = state.copyWith(
      devices: [
        for (final d in state.devices)
          d.key == device.key
              ? d.copyWith(
                  customName: custom,
                  clearCustomName: custom == null,
                  customType: kind,
                  clearCustomType: kind == null,
                )
              : d,
      ],
    );
  }

  void select(String ip) {
    state = state.copyWith(selectedIp: ip);
    if (!state.ports.containsKey(ip)) scanPorts(ip);
  }

  /// Quick COMMON-port scan for the detail panel.
  Future<void> scanPorts(String ip) async {
    if (state.scanningPorts.contains(ip)) return;
    // During the sweep hundreds of probes hold sockets, so connections to open
    // ports time out and the device looks closed. scan() runs it afterwards.
    if (state.running) return;
    final sweep = _sweep;
    state = state.copyWith(scanningPorts: {...state.scanningPorts, ip});
    final open = <PortResult>[];
    await for (final r in const PortScanner().scan(InternetAddress(ip), kCommonPorts)) {
      if (r.state == PortState.open) open.add(r);
    }
    if (sweep != _sweep || state.running) {
      // A sweep started meanwhile and starved these connections, so "closed"
      // can't be trusted. Drop it; scan() checks again when the sweep ends.
      state = state.copyWith(scanningPorts: {...state.scanningPorts}..remove(ip));
      // If that sweep already finished, its own re-check was skipped while
      // this one ran (scanningPorts), so run it now.
      if (!state.running && state.selectedIp == ip) unawaited(scanPorts(ip));
      return;
    }
    open.sort((a, b) => a.port.compareTo(b.port));
    final ports = {...state.ports, ip: open};
    state = state.copyWith(
      ports: ports,
      scanningPorts: {...state.scanningPorts}..remove(ip),
      devices: [
        for (final d in state.devices)
          d.host.ip == ip
              // copyWith keeps the user's name and type.
              ? d.copyWith(type: classifyDevice(d.host, openPorts: [for (final p in open) p.port]))
              : d,
      ],
    );
  }
}
