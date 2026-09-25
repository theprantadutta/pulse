import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models/session_tool.dart';
import '../services/net/dns.dart';
import '../services/net/ping_prober.dart';
import '../services/net/port_scanner.dart';
import 'ping_provider.dart';

enum PortPreset { common, wellKnown, custom }

@immutable
class PortScanState {
  const PortScanState({
    this.target = '',
    this.address,
    this.preset = PortPreset.common,
    this.customSpec = '22,80,443,8000-8100',
    this.ports = const [],
    this.results = const {},
    this.running = false,
    this.elapsed,
    this.error,
    this.concurrency = 128,
  });

  final String target;
  final String? address;
  final PortPreset preset;
  final String customSpec;
  final List<int> ports;
  final Map<int, PortResult> results;
  final bool running;
  final Duration? elapsed;
  final String? error;
  final int concurrency;

  int get scanned => results.length;
  List<PortResult> get open =>
      results.values.where((r) => r.state == PortState.open).toList()..sort((a, b) => a.port.compareTo(b.port));
  List<PortResult> get filtered =>
      results.values.where((r) => r.state == PortState.filtered).toList()..sort((a, b) => a.port.compareTo(b.port));

  String get rangeLabel => switch (preset) {
    PortPreset.common => 'COMMON',
    PortPreset.wellKnown => '1–1024',
    PortPreset.custom => customSpec,
  };

  PortScanState copyWith({
    String? target,
    String? address,
    PortPreset? preset,
    String? customSpec,
    List<int>? ports,
    Map<int, PortResult>? results,
    bool? running,
    Duration? elapsed,
    String? error,
    bool clearError = false,
  }) => PortScanState(
    target: target ?? this.target,
    address: address ?? this.address,
    preset: preset ?? this.preset,
    customSpec: customSpec ?? this.customSpec,
    ports: ports ?? this.ports,
    results: results ?? this.results,
    running: running ?? this.running,
    elapsed: elapsed ?? this.elapsed,
    error: clearError ? null : error ?? this.error,
    concurrency: concurrency,
  );
}

final portScanProvider = NotifierProvider<PortScanNotifier, PortScanState>(PortScanNotifier.new);

class PortScanNotifier extends Notifier<PortScanState> {
  StreamSubscription<PortResult>? _sub;

  @override
  PortScanState build() {
    ref.onDispose(() => _sub?.cancel());
    return const PortScanState();
  }

  void setPreset(PortPreset p) => state = state.copyWith(preset: p);

  void setCustom(String spec) => state = state.copyWith(customSpec: spec, preset: PortPreset.custom);

  List<int> _portsFor(PortScanState s) => switch (s.preset) {
    PortPreset.common => kCommonPorts,
    PortPreset.wellKnown => [for (var p = 1; p <= 1024; p++) p],
    PortPreset.custom => parsePortSpec(s.customSpec),
  };

  Future<void> scan(String target) async {
    target = target.trim();
    if (target.isEmpty) return;
    await _sub?.cancel();
    List<int> ports;
    try {
      ports = _portsFor(state);
    } on FormatException catch (e) {
      state = state.copyWith(error: e.message);
      return;
    }
    if (ports.length > 20000) {
      state = state.copyWith(error: 'Pick at most 20,000 ports per scan.');
      return;
    }
    state = state.copyWith(target: target, ports: ports, results: const {}, running: true, clearError: true);
    final InternetAddress address;
    try {
      address = await Dns.resolve(target, family: ProbeFamily.ipv4);
    } on DnsFailure catch (e) {
      state = state.copyWith(running: false, error: '$e');
      return;
    }
    state = state.copyWith(address: address.address);
    final started = DateTime.now();
    final results = <int, PortResult>{};
    var lastPush = DateTime.fromMillisecondsSinceEpoch(0);
    final mobile = Platform.isAndroid || Platform.isIOS;
    final done = Completer<void>();
    _sub = PortScanner(concurrency: mobile ? 64 : 128)
        .scan(address, ports)
        .listen(
          (r) {
            results[r.port] = r;
            final now = DateTime.now();
            if (now.difference(lastPush).inMilliseconds > 80) {
              lastPush = now;
              state = state.copyWith(results: Map.of(results), elapsed: now.difference(started));
            }
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );
    await done.future;
    state = state.copyWith(results: Map.of(results), running: false, elapsed: DateTime.now().difference(started));
    await _save(started);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    state = state.copyWith(running: false);
  }

  Future<void> _save(DateTime started) async {
    final s = state;
    final open = s.open;
    await ref
        .read(historyRepositoryProvider)
        .save(
          tool: SessionTool.ports,
          target: s.target,
          startedAt: started,
          endedAt: DateTime.now(),
          summary: '${open.length} open${open.isEmpty ? '' : ' · ${open.take(5).map((p) => p.port).join(', ')}'}',
          payload: {
            'address': s.address,
            'range': s.rangeLabel,
            'scanned': s.scanned,
            'open': [for (final p in open) p.toJson()],
            'filtered': s.filtered.length,
          },
        );
  }
}
