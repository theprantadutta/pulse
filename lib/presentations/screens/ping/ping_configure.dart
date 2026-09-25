import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/wire/wire.dart';
import '../../../data/catalog/target_catalog.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/ping_models.dart';
import '../../../providers/ping_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/net/gateway.dart';
import '../../../services/net/ping_prober.dart';

final gatewayProvider = FutureProvider<String?>((ref) => Gateway.ipv4());

/// PARAMETERS: COUNT / INTERVAL / TIMEOUT / PACKET SIZE / IP VERSION.
class PingParametersPanel extends ConsumerWidget {
  const PingParametersPanel({super.key, this.showIpVersion = true, this.compact = false});
  final bool showIpVersion;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final p = ref.watch(pingDraftProvider.select((d) => d.params));
    final draft = ref.read(pingDraftProvider.notifier);
    Widget row(String label, String hint, Widget control) => Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 20, vertical: compact ? 12 : 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: w.ink, width: kWireBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: WireType.label())),
              if (!compact) Text(hint, style: WireType.body(11).copyWith(color: w.text3, height: 1.2)),
            ],
          ),
          const SizedBox(height: 8),
          control,
        ],
      ),
    );
    final seg = WireType.data(13);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(
          'COUNT',
          'packets',
          WireSegmented<int>(
            textStyle: seg,
            height: compact ? 42 : 38,
            options: [for (final c in PingParams.counts) (c, c == 0 ? '∞' : '$c')],
            selected: p.count,
            onChanged: (v) => draft.setParams(p.copyWith(count: v)),
          ),
        ),
        row(
          compact ? 'INTERVAL · SEC' : 'INTERVAL',
          'seconds',
          WireSegmented<int>(
            textStyle: seg,
            height: compact ? 42 : 38,
            options: [for (final v in PingParams.intervals) (v, '${v / 1000}'.replaceAll('.0', ''))],
            selected: p.intervalMs,
            onChanged: (v) => draft.setParams(p.copyWith(intervalMs: v)),
          ),
        ),
        row(
          compact ? 'TIMEOUT · SEC' : 'TIMEOUT',
          'seconds',
          WireSegmented<int>(
            textStyle: seg,
            height: compact ? 42 : 38,
            options: [for (final v in PingParams.timeouts) (v, '$v')],
            selected: p.timeoutSec,
            onChanged: (v) => draft.setParams(p.copyWith(timeoutSec: v)),
          ),
        ),
        row(
          compact ? 'PACKET SIZE · BYTES' : 'PACKET SIZE',
          PingProber.supportsPacketSize ? 'bytes' : 'fixed by iOS',
          WireSegmented<int>(
            textStyle: seg,
            height: compact ? 42 : 38,
            enabled: PingProber.supportsPacketSize,
            options: [for (final v in PingParams.sizes) (v, '$v')],
            selected: p.packetSize,
            onChanged: (v) => draft.setParams(p.copyWith(packetSize: v)),
          ),
        ),
        if (showIpVersion)
          row(
            'IP VERSION',
            'protocol',
            WireSegmented<IpVersionPref>(
              textStyle: seg,
              height: compact ? 42 : 38,
              options: const [
                (IpVersionPref.auto, 'AUTO'),
                (IpVersionPref.ipv4, 'IPv4'),
                (IpVersionPref.ipv6, 'IPv6'),
                (IpVersionPref.both, 'BOTH'),
              ],
              selected: p.ipVersion,
              onChanged: (v) => draft.setParams(p.copyWith(ipVersion: v)),
            ),
          ),
      ],
    );
  }
}

class SaveAsDefaultRow extends ConsumerWidget {
  const SaveAsDefaultRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final on = ref.watch(settingsProvider.select((s) => s.saveAsDefault));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: w.ink, width: kWireBorder),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: Text('SAVE AS DEFAULT', style: WireType.label(12))),
          WireToggle(
            value: on,
            semanticLabel: 'Save as default',
            onChanged: (v) async {
              await ref.read(settingsProvider.notifier).update((s) => s.copyWith(saveAsDefault: v));
              if (v) await ref.read(pingDraftProvider.notifier).setParams(ref.read(pingDraftProvider).params);
            },
          ),
        ],
      ),
    );
  }
}

/// One suggestion row.
class _Suggestion {
  const _Suggestion(this.host, this.desc, this.tag, {this.name});
  final String host;
  final String desc;
  final String tag;
  final String? name;
}

List<_Suggestion> _suggest(
  String query,
  List<({String host, String? name, double? avg})> recent,
  List<SavedTarget> saved,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final out = <_Suggestion>[];
  final seen = <String>{};
  void add(_Suggestion s) {
    if (out.length < 6 && seen.add(s.host.toLowerCase())) out.add(s);
  }

  for (final t in saved) {
    if (t.name.toLowerCase().contains(q) || t.host.toLowerCase().contains(q)) {
      add(_Suggestion(t.host, t.name, 'SAVED', name: t.name));
    }
  }
  for (final r in recent) {
    if (r.host.toLowerCase().contains(q) || (r.name?.toLowerCase().contains(q) ?? false)) {
      add(_Suggestion(r.host, '${r.name ?? 'recent'} · last ${fmtMs(r.avg)} ms', 'RECENT', name: r.name));
    }
  }
  for (final p in kPresetTargets) {
    if (p.host.contains(q) || (p.name?.toLowerCase().contains(q) ?? false) || p.description.toLowerCase().contains(q)) {
      add(_Suggestion(p.host, p.description, 'PRESET'));
    }
  }
  for (final d in kDomainCatalog) {
    if (d.host.startsWith(q)) add(_Suggestion(d.host, d.description, 'DOMAIN'));
  }
  for (final d in kDomainCatalog) {
    if (d.host.contains(q)) add(_Suggestion(d.host, d.description, 'DOMAIN'));
  }
  return out;
}

/// Main column of the Configure view: suggestions, quick targets and the
/// saved (named) targets with multi-select → ping selected.
class PingConfigureMain extends ConsumerStatefulWidget {
  const PingConfigureMain({super.key, required this.onPicked, required this.onStarted, this.embedded = false});

  /// Lays out inside another scroll view (mobile sheet).
  final bool embedded;

  /// A suggestion or quick target was chosen (fills the target field).
  final void Function(String host, String? name) onPicked;

  /// Pings were started from this view.
  final VoidCallback onStarted;

  @override
  ConsumerState<PingConfigureMain> createState() => _PingConfigureMainState();
}

class _PingConfigureMainState extends ConsumerState<PingConfigureMain> {
  final _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final draft = ref.watch(pingDraftProvider);
    final recent = ref.watch(recentTargetsProvider).value ?? const [];
    final saved = ref.watch(savedTargetsProvider).value ?? const <SavedTarget>[];
    final gateway = ref.watch(gatewayProvider).value;
    final suggestions = _suggest(draft.host, recent, saved);
    _selected.removeWhere((id) => !saved.any((t) => t.id == id));

    final quick = <({String name, String host, String sub})>[
      (name: 'Google DNS', host: '8.8.8.8', sub: '8.8.8.8'),
      (name: 'Cloudflare', host: '1.1.1.1', sub: '1.1.1.1'),
      (name: 'Router', host: gateway ?? '', sub: gateway ?? 'no gateway'),
      (name: 'AWS Mumbai', host: 'ec2.ap-south-1.amazonaws.com', sub: 'ap-south-1'),
      (name: 'GitHub', host: 'github.com', sub: 'github.com'),
    ];

    return ListView(
      shrinkWrap: widget.embedded,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.zero,
      children: [
        if (suggestions.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: w.ink, width: kWireBorder),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const WireSectionBar('Suggestions'),
                for (var i = 0; i < suggestions.length; i++)
                  WireRow(
                    highlight: i == 0 ? WireRowHighlight.tint : WireRowHighlight.none,
                    onTap: () => widget.onPicked(suggestions[i].host, suggestions[i].name),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(suggestions[i].host, style: WireType.data(16)),
                              Text(suggestions[i].desc, style: WireType.body(12).copyWith(color: w.text3, height: 1.3)),
                            ],
                          ),
                        ),
                        Text(suggestions[i].tag, style: WireType.label()),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text('QUICK TARGETS', style: WireType.label()),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth < 480 ? 2 : 3;
              final rows = (6 / cols).ceil();
              Widget cell(int i, WireSides sides) {
                if (i == 5) {
                  return _QuickCell(
                    name: '+ Add',
                    sub: 'save a named target',
                    sides: sides,
                    onTap: () => showSavedTargetDialog(context, ref, host: draft.host, name: draft.name),
                  );
                }
                final q = quick[i];
                return _QuickCell(
                  name: q.name,
                  sub: q.sub,
                  sides: sides,
                  onTap: q.host.isEmpty ? null : () => widget.onPicked(q.host, q.name),
                );
              }

              return WireBox(
                child: Column(
                  children: [
                    for (var r = 0; r < rows; r++)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var c = 0; c < cols; c++)
                              Expanded(
                                child: cell(r * cols + c, WireSides(right: c < cols - 1, bottom: r < rows - 1)),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
          child: Row(
            children: [
              Expanded(child: Text('SAVED TARGETS · ${saved.length}', style: WireType.label())),
              if (saved.isNotEmpty)
                WirePressable(
                  onTap: () => setState(() {
                    if (_selected.length == saved.length) {
                      _selected.clear();
                    } else {
                      _selected.addAll(saved.map((t) => t.id));
                    }
                  }),
                  builder: (context, c, s) => Container(
                    color: c.bg,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      _selected.length == saved.length ? 'SELECT NONE' : 'SELECT ALL',
                      style: WireType.label().copyWith(color: c.fg),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: WireBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (saved.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Name the machines you check often — "Office PC", "Library PC" — '
                      'then ping any number of them at once.',
                      style: WireType.body(13).copyWith(color: w.text2),
                    ),
                  ),
                for (final t in saved)
                  WireRow(
                    selected: _selected.contains(t.id),
                    onTap: () => setState(() {
                      _selected.contains(t.id) ? _selected.remove(t.id) : _selected.add(t.id);
                    }),
                    padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                    child: Row(
                      children: [
                        _Check(on: _selected.contains(t.id)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.name.toUpperCase(), style: WireType.title(20)),
                              Text(t.host, style: WireType.body(12).copyWith(color: w.text2, height: 1.2)),
                            ],
                          ),
                        ),
                        _RowAction(
                          label: 'EDIT',
                          onTap: () => showSavedTargetDialog(context, ref, existing: t),
                        ),
                        _RowAction(
                          label: '▶',
                          tooltip: 'Ping ${t.name}',
                          onTap: () async {
                            await ref
                                .read(pingBoardProvider.notifier)
                                .start(t.host, name: t.name, params: ref.read(pingDraftProvider).params);
                            widget.onStarted();
                          },
                        ),
                      ],
                    ),
                  ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: WireButton(
                          label: 'Save target',
                          glyph: '+',
                          bordered: false,
                          sides: WireSides.onlyRight,
                          fontSize: 16,
                          onPressed: () => showSavedTargetDialog(context, ref, host: draft.host, name: draft.name),
                        ),
                      ),
                      Expanded(
                        child: WireButton(
                          label: _selected.isEmpty ? 'Ping selected' : 'Ping ${_selected.length} selected',
                          glyph: '▶',
                          bordered: false,
                          fontSize: 16,
                          variant: WireButtonVariant.primary,
                          onPressed: _selected.isEmpty
                              ? null
                              : () async {
                                  final picks = saved.where((t) => _selected.contains(t.id));
                                  final n = await ref.read(pingBoardProvider.notifier).startMany([
                                    for (final t in picks) (host: t.host, name: t.name),
                                  ], params: ref.read(pingDraftProvider).params);
                                  if (!context.mounted) return;
                                  if (n < picks.length) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Started $n — at most $kMaxLivePings live pings at once.'),
                                      ),
                                    );
                                  }
                                  setState(_selected.clear);
                                  widget.onStarted();
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickCell extends StatelessWidget {
  const _QuickCell({required this.name, required this.sub, required this.sides, this.onTap});
  final String name;
  final String sub;
  final WireSides sides;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return WireCell(
      onTap: onTap,
      sides: sides,
      padding: const EdgeInsets.all(16),
      alignment: Alignment.topLeft,
      semanticLabel: name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: WireType.title(22)),
          const SizedBox(height: 4),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: WireType.body(12).copyWith(color: w.text3, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? w.ink : Colors.transparent,
        border: Border.all(color: w.ink, width: kWireBorder),
      ),
      child: on ? Text('✓', style: WireType.data(13).copyWith(color: w.background, height: 1)) : null,
    );
  }
}

class _RowAction extends StatelessWidget {
  const _RowAction({required this.label, required this.onTap, this.tooltip});
  final String label;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return WirePressable(
      onTap: onTap,
      tooltip: tooltip,
      semanticLabel: tooltip ?? label,
      builder: (context, c, s) => Container(
        constraints: const BoxConstraints(minWidth: WireLayout.minHit, minHeight: WireLayout.minHit),
        color: c.bg,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(label, style: WireType.label(12).copyWith(color: c.fg)),
      ),
    );
  }
}

/// Add / edit a named target.
Future<void> showSavedTargetDialog(
  BuildContext context,
  WidgetRef ref, {
  SavedTarget? existing,
  String host = '',
  String name = '',
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _SavedTargetDialog(existing: existing, host: host, name: name),
  );
}

class _SavedTargetDialog extends ConsumerStatefulWidget {
  const _SavedTargetDialog({this.existing, required this.host, required this.name});
  final SavedTarget? existing;
  final String host;
  final String name;

  @override
  ConsumerState<_SavedTargetDialog> createState() => _SavedTargetDialogState();
}

class _SavedTargetDialogState extends ConsumerState<_SavedTargetDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? widget.name);
  late final _host = TextEditingController(text: widget.existing?.host ?? widget.host);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final host = _host.text.trim();
    if (name.isEmpty || host.isEmpty) {
      setState(() => _error = 'Give it a name and a host or IP.');
      return;
    }
    if (!RegExp(r'^[A-Za-z0-9.\-:%_]+$').hasMatch(host) ||
        (host.contains(':') && InternetAddress.tryParse(host) == null)) {
      setState(() => _error = 'That does not look like a host name or IP address.');
      return;
    }
    final repo = ref.read(savedTargetsRepositoryProvider);
    if (widget.existing == null) {
      await repo.add(name, host);
    } else {
      await repo.update(widget.existing!.id, name: name, host: host);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: w.ink,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Text(
                widget.existing == null ? 'SAVE TARGET' : 'EDIT TARGET',
                style: WireType.title(26).copyWith(color: w.background),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text('NAME', style: WireType.label()),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: WireInput(controller: _name, hint: 'Office PC', autofocus: true, onSubmitted: (_) => _save()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Text('HOST OR IP', style: WireType.label()),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: WireInput(
                controller: _host,
                hint: '192.168.1.20',
                keyboardType: TextInputType.url,
                onSubmitted: (_) => _save(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(_error!, style: WireType.body(12).copyWith(color: w.signal)),
              ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: w.ink, width: kWireBorder),
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.existing != null)
                      Expanded(
                        child: WireButton(
                          label: 'Delete',
                          bordered: false,
                          sides: WireSides.onlyRight,
                          fontSize: 16,
                          onPressed: () async {
                            await ref.read(savedTargetsRepositoryProvider).delete(widget.existing!.id);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                        ),
                      ),
                    Expanded(
                      child: WireButton(
                        label: 'Cancel',
                        bordered: false,
                        sides: WireSides.onlyRight,
                        fontSize: 16,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Expanded(
                      child: WireButton(
                        label: 'Save',
                        variant: WireButtonVariant.primary,
                        bordered: false,
                        fontSize: 16,
                        onPressed: _save,
                      ),
                    ),
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
