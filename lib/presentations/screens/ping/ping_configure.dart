import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/pulse/pulse.dart';
import '../../../data/catalog/target_catalog.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/ping_models.dart';
import '../../../providers/alerts_provider.dart';
import '../../../providers/ping_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/background/monitor_engine.dart';
import '../../../services/net/gateway.dart';
import '../../../services/net/ping_prober.dart';
import '../../navigation/destinations.dart';
import 'ping_widgets.dart';

/// The default gateway (the "Router" host).
final gatewayProvider = FutureProvider<String?>((ref) => Gateway.ipv4());

bool _validHost(String host) =>
    RegExp(r'^[A-Za-z0-9.\-:%_]+$').hasMatch(host) && (!host.contains(':') || InternetAddress.tryParse(host) != null);

// ---------------------------------------------------------------------------
// Sheet frame
// ---------------------------------------------------------------------------

Future<T?> _showSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
  useRootNavigator: true,
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: builder,
);

/// Title, scrolling body and a pinned footer, sized to the content.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, this.subtitle, required this.children, this.footer, this.trailing});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? footer;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // Landscape tablets with the keyboard up leave ~200 dp: a pinned footer
    // would cover the fields, so it scrolls with them instead.
    final room = MediaQuery.sizeOf(context).height - MediaQuery.viewInsetsOf(context).bottom;
    final pinFooter = room >= 420;
    final footer = this.footer == null
        ? null
        : Padding(padding: EdgeInsets.fromLTRB(pinFooter ? 16 : 0, 4, pinFooter ? 16 : 0, 16), child: this.footer);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(header: true, child: Text(title, style: context.type.headlineSmall)),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: context.type.bodyMedium!.copyWith(color: context.colors.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [...children, if (!pinFooter) ?footer],
              ),
            ),
            if (pinFooter) ?footer,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ping options editor (count / interval / timeout / packet size / IP version)
// ---------------------------------------------------------------------------

enum PingOption { count, interval, timeout, size, ipVersion }

/// Every ping option as a connected button group. [only] shows one of them.
class PingParamsEditor extends StatelessWidget {
  const PingParamsEditor({super.key, required this.params, required this.onChanged, this.only});
  final PingParams params;
  final ValueChanged<PingParams> onChanged;
  final PingOption? only;

  @override
  Widget build(BuildContext context) {
    final p = params;
    Widget field(String label, String? hint, Widget group) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Row(
              children: [
                Expanded(child: Text(label, style: context.type.titleSmall)),
                if (hint != null)
                  Text(hint, style: context.type.bodySmall!.copyWith(color: context.colors.onSurfaceVariant)),
              ],
            ),
          ),
          group,
        ],
      ),
    );
    bool show(PingOption o) => only == null || only == o;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (show(PingOption.interval))
          field(
            'Interval',
            'time between pings',
            PulseButtonGroup<int>(
              small: true,
              segments: [for (final v in PingParams.intervals) PulseSegment(v, intervalLabel(v))],
              selected: p.intervalMs,
              onChanged: (v) => onChanged(p.copyWith(intervalMs: v)),
            ),
          ),
        if (show(PingOption.size))
          field(
            'Packet size',
            PingProber.supportsPacketSize ? 'bytes' : 'fixed by iOS',
            PulseButtonGroup<int>(
              small: true,
              segments: [for (final v in PingParams.sizes) PulseSegment(v, '$v B')],
              selected: p.packetSize,
              onChanged: PingProber.supportsPacketSize ? (v) => onChanged(p.copyWith(packetSize: v)) : null,
            ),
          ),
        if (show(PingOption.timeout))
          field(
            'Timeout',
            'wait for a reply',
            PulseButtonGroup<int>(
              small: true,
              segments: [for (final v in PingParams.timeouts) PulseSegment(v, '$v s')],
              selected: p.timeoutSec,
              onChanged: (v) => onChanged(p.copyWith(timeoutSec: v)),
            ),
          ),
        if (show(PingOption.count))
          field(
            'Count',
            'pings, then stop',
            PulseButtonGroup<int>(
              small: true,
              segments: [for (final v in PingParams.counts) PulseSegment(v, v == 0 ? 'Continuous' : '$v')],
              selected: p.count,
              onChanged: (v) => onChanged(p.copyWith(count: v)),
            ),
          ),
        if (show(PingOption.ipVersion))
          field(
            'IP version',
            null,
            PulseButtonGroup<IpVersionPref>(
              small: true,
              segments: const [
                PulseSegment(IpVersionPref.auto, 'Auto'),
                PulseSegment(IpVersionPref.ipv4, 'IPv4'),
                PulseSegment(IpVersionPref.ipv6, 'IPv6'),
                PulseSegment(IpVersionPref.both, 'Both'),
              ],
              selected: p.ipVersion,
              onChanged: (v) => onChanged(p.copyWith(ipVersion: v)),
            ),
          ),
      ],
    );
  }
}

/// "Save as default" switch: new pings start with these options.
class _SaveAsDefault extends ConsumerWidget {
  const _SaveAsDefault();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(settingsProvider.select((s) => s.saveAsDefault));
    return PulseSwitchItem(
      title: 'Save as default',
      subtitle: 'Remember these options for new pings',
      value: on,
      onChanged: (v) async {
        await ref.read(settingsProvider.notifier).update((s) => s.copyWith(saveAsDefault: v));
        if (v) await ref.read(pingDraftProvider.notifier).setParams(ref.read(pingDraftProvider).params);
      },
    );
  }
}

String _optionsSummary(PingParams p) => [
  'Every ${intervalLabel(p.intervalMs)}',
  '${p.packetSize} B',
  'timeout ${p.timeoutSec} s',
  p.count == 0 ? 'continuous' : '${p.count} pings',
  if (p.ipVersion != IpVersionPref.auto) ipVersionLabel(p.ipVersion),
].join(' · ');

// ---------------------------------------------------------------------------
// Ping settings (defaults for new hosts)
// ---------------------------------------------------------------------------

/// Home "Ping settings": options for new hosts, save as default, apply to the
/// hosts already on the board, clear stopped hosts.
Future<void> showPingSettingsSheet(BuildContext context) => _showSheet(context, (_) => const _PingSettingsSheet());

class _PingSettingsSheet extends ConsumerWidget {
  const _PingSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(pingDraftProvider.select((d) => d.params));
    final board = ref.watch(pingBoardProvider);
    final stopped = board.sessions.length - board.liveCount;
    return _SheetFrame(
      title: 'Ping settings',
      subtitle: 'Used for every host you add',
      trailing: PulseButton(
        label: 'Reset',
        style: PulseButtonStyle.text,
        size: PulseButtonSize.small,
        onPressed: () => ref.read(pingDraftProvider.notifier).reset(),
      ),
      footer: Row(
        children: [
          if (board.liveCount > 0) ...[
            Expanded(
              child: PulseButton(
                label: board.liveCount == 1 ? 'Apply to 1 live host' : 'Apply to ${board.liveCount} live hosts',
                style: PulseButtonStyle.tonal,
                size: PulseButtonSize.large,
                expand: true,
                onPressed: () async {
                  await restartAll(context, ref, params: params, onlyRunning: true);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: PulseButton(
              label: 'Done',
              size: PulseButtonSize.large,
              expand: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
      children: [
        PingParamsEditor(params: params, onChanged: (p) => ref.read(pingDraftProvider.notifier).setParams(p)),
        const _SaveAsDefault(),
        if (stopped > 0) ...[
          const SizedBox(height: 8),
          PulseListItem(
            title: stopped == 1 ? 'Clear 1 stopped host' : 'Clear $stopped stopped hosts',
            subtitle: 'Their results stay in History',
            leading: PulseIcon(PulseIcons.trash, size: 22, color: context.colors.onSurfaceVariant),
            onTap: () {
              ref.read(pingBoardProvider.notifier).clearFinished();
              Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Per-host options
// ---------------------------------------------------------------------------

/// Ping detail tune / setting chips: change this host's options. Applying
/// restarts the host with them (the finished run is saved to History).
Future<void> showHostOptionsSheet(BuildContext context, PingSession session, {PingOption? only}) =>
    _showSheet(context, (_) => _HostOptionsSheet(session: session, only: only));

class _HostOptionsSheet extends ConsumerStatefulWidget {
  const _HostOptionsSheet({required this.session, this.only});
  final PingSession session;
  final PingOption? only;

  @override
  ConsumerState<_HostOptionsSheet> createState() => _HostOptionsSheetState();
}

class _HostOptionsSheetState extends ConsumerState<_HostOptionsSheet> {
  late PingParams _params = widget.session.params;

  @override
  Widget build(BuildContext context) {
    final changed = _params.toJson().toString() != widget.session.params.toJson().toString();
    final title = switch (widget.only) {
      PingOption.interval => 'Interval',
      PingOption.size => 'Packet size',
      PingOption.timeout => 'Timeout',
      PingOption.count => 'Count',
      PingOption.ipVersion => 'IP version',
      null => 'Ping options',
    };
    return _SheetFrame(
      title: title,
      subtitle: widget.session.title,
      footer: PulseButton(
        label: !changed && widget.session.running
            ? 'Done'
            : (widget.session.running ? 'Apply and restart' : 'Apply and start'),
        size: PulseButtonSize.large,
        expand: true,
        onPressed: () async {
          if (!changed && widget.session.running) {
            Navigator.of(context).pop();
            return;
          }
          final router = GoRouter.maybeOf(context);
          final onDetail = router?.state.uri.path == Routes.pingDetail;
          final n = ref.read(pingBoardProvider.notifier);
          Navigator.of(context).pop();
          final id = await n.restart(widget.session.id, params: _params);
          if (id != null && onDetail) router!.go('${Routes.pingDetail}?id=${Uri.encodeQueryComponent(id)}');
        },
      ),
      children: [
        PingParamsEditor(params: _params, only: widget.only, onChanged: (p) => setState(() => _params = p)),
        if (widget.only != null)
          PulseButton(
            label: 'All options',
            style: PulseButtonStyle.text,
            icon: PulseIcons.tune,
            onPressed: () {
              Navigator.of(context).pop();
              showHostOptionsSheet(context, widget.session);
            },
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Add / edit host
// ---------------------------------------------------------------------------

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
      add(_Suggestion(t.host, t.name, 'Saved', name: t.name));
    }
  }
  for (final r in recent) {
    if (r.host.toLowerCase().contains(q) || (r.name?.toLowerCase().contains(q) ?? false)) {
      add(_Suggestion(r.host, '${r.name ?? 'Recent'} · last ${fmtMs(r.avg)} ms', 'Recent', name: r.name));
    }
  }
  for (final p in kPresetTargets) {
    if (p.host.contains(q) || (p.name?.toLowerCase().contains(q) ?? false) || p.description.toLowerCase().contains(q)) {
      add(_Suggestion(p.host, p.description, 'Preset', name: p.name));
    }
  }
  for (final d in kDomainCatalog) {
    if (d.host.startsWith(q)) add(_Suggestion(d.host, d.description, 'Domain'));
  }
  for (final d in kDomainCatalog) {
    if (d.host.contains(q)) add(_Suggestion(d.host, d.description, 'Domain'));
  }
  return out;
}

/// Add a host (target, optional name, suggestions, quick targets, recent and
/// saved targets with multi-select, options) or edit one on the board.
Future<void> showAddHostSheet(BuildContext context, {PingSession? edit, String? host, String? name}) =>
    _showSheet(context, (_) => _AddHostSheet(edit: edit, host: host, name: name));

class _AddHostSheet extends ConsumerStatefulWidget {
  const _AddHostSheet({this.edit, this.host, this.name});
  final PingSession? edit;
  final String? host;
  final String? name;

  @override
  ConsumerState<_AddHostSheet> createState() => _AddHostSheetState();
}

class _AddHostSheetState extends ConsumerState<_AddHostSheet> {
  // A new host starts from the last draft (what was typed before, like the
  // old configure screen); editing starts from the host itself.
  late final _host = TextEditingController(text: widget.edit?.host ?? widget.host ?? ref.read(pingDraftProvider).host);
  late final _name = TextEditingController(text: widget.edit?.name ?? widget.name ?? ref.read(pingDraftProvider).name);
  late PingParams? _editParams = widget.edit?.params;
  final _selected = <int>{};
  bool _options = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.edit == null) {
      // Keep the draft as you type so a dismissed sheet doesn't lose it.
      _host.addListener(() => ref.read(pingDraftProvider.notifier).setHost(_host.text.trim()));
      _name.addListener(() => ref.read(pingDraftProvider.notifier).setName(_name.text.trim()));
    }
  }

  @override
  void dispose() {
    _host.dispose();
    _name.dispose();
    super.dispose();
  }

  PingParams get _params => _editParams ?? ref.read(pingDraftProvider).params;

  void _pick(String host, String? name) => setState(() {
    _host.text = host;
    _host.selection = TextSelection.collapsed(offset: host.length);
    if (name != null && _name.text.trim().isEmpty) _name.text = name;
    _error = null;
  });

  Future<void> _submit() async {
    final host = _host.text.trim();
    if (host.isEmpty) {
      setState(() => _error = 'Enter a host name or IP address.');
      return;
    }
    if (!_validHost(host)) {
      setState(() => _error = 'That does not look like a host name or IP address.');
      return;
    }
    final n = ref.read(pingBoardProvider.notifier);
    if (widget.edit != null) {
      final router = GoRouter.maybeOf(context);
      final onDetail = router?.state.uri.path == Routes.pingDetail;
      final name = _name.text.trim();
      final params = _params;
      Navigator.of(context).pop();
      final id = await n.restart(widget.edit!.id, host: host, name: name, params: params);
      if (id != null && onDetail) router!.go('${Routes.pingDetail}?id=${Uri.encodeQueryComponent(id)}');
      return;
    }
    final id = await n.start(host, name: _name.text, params: _params);
    if (!mounted) return;
    if (id == null) {
      showPingLimit(context);
      return;
    }
    // Keep the host for a quick repeat, but don't name the next host the same.
    ref.read(pingDraftProvider.notifier)
      ..setHost(host)
      ..setName('');
    Navigator.of(context).pop();
  }

  Future<void> _startSaved(Iterable<SavedTarget> targets) async {
    final list = targets.toList();
    final n = await ref.read(pingBoardProvider.notifier).startMany([
      for (final t in list) (host: t.host, name: t.name),
    ], params: _params);
    if (!mounted) return;
    if (n < list.length) showPingLimit(context);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final editing = widget.edit != null;
    final recent = ref.watch(recentTargetsProvider).value ?? const [];
    final saved = ref.watch(savedTargetsProvider).value ?? const <SavedTarget>[];
    final gateway = ref.watch(gatewayProvider).value;
    final draftParams = ref.watch(pingDraftProvider.select((d) => d.params));
    final params = _editParams ?? draftParams;
    _selected.removeWhere((id) => !saved.any((t) => t.id == id));
    final suggestions = _suggest(_host.text, recent, saved);
    final quick = <({String name, String host})>[
      if (gateway != null) (name: 'Router', host: gateway),
      (name: 'Google DNS', host: '8.8.8.8'),
      (name: 'Cloudflare', host: '1.1.1.1'),
      (name: 'GitHub', host: 'github.com'),
      (name: 'AWS Mumbai', host: 'ec2.ap-south-1.amazonaws.com'),
    ];

    return _SheetFrame(
      title: editing ? 'Edit host' : 'Add host',
      subtitle: editing ? 'Restarts the ping with the new target' : 'Ping a host name or IP address',
      footer: PulseButton(
        label: editing ? 'Save and restart' : 'Start ping',
        icon: editing ? PulseIcons.check : PulseIcons.play,
        size: PulseButtonSize.large,
        expand: true,
        onPressed: _submit,
      ),
      children: [
        PulseTargetField(
          controller: _host,
          hint: 'Host or IP, e.g. 1.1.1.1',
          autofocus: !editing && (widget.host?.isEmpty ?? true),
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 8),
        PulseTargetField(
          controller: _name,
          hint: 'Name (optional), e.g. Office PC',
          icon: PulseIcons.pin,
          keyboardType: TextInputType.text,
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(_error!, style: context.type.bodySmall!.copyWith(color: c.error)),
          ),
        if (suggestions.isNotEmpty) ...[
          const PulseSectionLabel('Suggestions'),
          PulseSegmentedList(
            animate: false,
            children: [
              for (final s in suggestions)
                PulseListItem(
                  title: s.host,
                  subtitle: s.desc,
                  color: c.surfaceContainer,
                  trailing: PulsePill(s.tag, height: 24),
                  onTap: () => _pick(s.host, s.name),
                ),
            ],
          ),
        ],
        if (!editing) ...[
          const PulseSectionLabel('Quick targets'),
          PulseChipRow(
            children: [
              for (final q in quick)
                PulseChip(
                  label: q.name,
                  small: true,
                  selected: _host.text.trim() == q.host,
                  onTap: () => _pick(q.host, q.name),
                ),
            ],
          ),
        ],
        PulseSectionLabel(
          'Options',
          trailing: PulseButton(
            label: _options ? 'Hide' : 'Change',
            style: PulseButtonStyle.text,
            size: PulseButtonSize.small,
            onPressed: () => setState(() => _options = !_options),
          ),
        ),
        if (!_options)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(_optionsSummary(params), style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant)),
          )
        else ...[
          PingParamsEditor(
            params: params,
            onChanged: (p) {
              if (editing) {
                setState(() => _editParams = p);
              } else {
                ref.read(pingDraftProvider.notifier).setParams(p);
              }
            },
          ),
          if (!editing) const _SaveAsDefault(),
        ],
        if (!editing && recent.isNotEmpty) ...[
          const PulseSectionLabel('Recent'),
          PulseSegmentedList(
            animate: false,
            children: [
              for (final r in recent.take(5))
                PulseListItem(
                  title: r.name?.isNotEmpty == true ? r.name! : r.host,
                  subtitle: r.name?.isNotEmpty == true ? r.host : 'Pinged before',
                  leading: HostBadge(host: r.host, name: r.name, gateway: gateway),
                  trailing: r.avg == null
                      ? null
                      : PulseNumber(fmtMs(r.avg), unit: 'ms', unitScale: .6, style: pulseNumber(16)),
                  onTap: () => _pick(r.host, r.name),
                ),
            ],
          ),
        ],
        if (!editing) ...[
          PulseSectionLabel(
            saved.isEmpty ? 'Saved targets' : 'Saved targets · ${saved.length}',
            trailing: saved.isEmpty
                ? null
                : PulseButton(
                    label: _selected.length == saved.length ? 'Select none' : 'Select all',
                    style: PulseButtonStyle.text,
                    size: PulseButtonSize.small,
                    onPressed: () => setState(() {
                      if (_selected.length == saved.length) {
                        _selected.clear();
                      } else {
                        _selected.addAll(saved.map((t) => t.id));
                      }
                    }),
                  ),
          ),
          if (saved.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                'Name the machines you check often, like "Office PC" or "Library PC", then ping any number of them at once.',
                style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant),
              ),
            )
          else
            PulseSegmentedList(
              animate: false,
              children: [
                for (final t in saved)
                  PulseListItem(
                    title: t.name,
                    subtitle: t.host,
                    selected: _selected.contains(t.id),
                    padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                    leading: Checkbox(
                      value: _selected.contains(t.id),
                      onChanged: (_) => setState(() {
                        _selected.contains(t.id) ? _selected.remove(t.id) : _selected.add(t.id);
                      }),
                    ),
                    onTap: () => setState(() {
                      _selected.contains(t.id) ? _selected.remove(t.id) : _selected.add(t.id);
                    }),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PulseIconButton(
                          icon: PulseIcons.tune,
                          tooltip: 'Edit ${t.name}',
                          iconSize: 20,
                          onPressed: () => showSavedTargetDialog(context, existing: t),
                        ),
                        PulseIconButton(
                          icon: PulseIcons.play,
                          tooltip: 'Ping ${t.name}',
                          iconSize: 20,
                          onPressed: () => _startSaved([t]),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PulseButton(
                  label: 'Save target',
                  icon: PulseIcons.plus,
                  style: PulseButtonStyle.outlined,
                  expand: true,
                  onPressed: () => showSavedTargetDialog(context, host: _host.text.trim(), name: _name.text.trim()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PulseButton(
                  label: _selected.isEmpty ? 'Ping selected' : 'Ping ${_selected.length} selected',
                  icon: PulseIcons.play,
                  style: PulseButtonStyle.tonal,
                  expand: true,
                  onPressed: _selected.isEmpty ? null : () => _startSaved(saved.where((t) => _selected.contains(t.id))),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Saved target dialog
// ---------------------------------------------------------------------------

/// Add / edit / delete a named target.
Future<void> showSavedTargetDialog(BuildContext context, {SavedTarget? existing, String host = '', String name = ''}) {
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
    if (!_validHost(host)) {
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
    return AlertDialog(
      title: Text(widget.existing == null ? 'Save target' : 'Edit target'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PulseTargetField(
              controller: _name,
              hint: 'Name, e.g. Office PC',
              icon: PulseIcons.pin,
              keyboardType: TextInputType.text,
              autofocus: true,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            PulseTargetField(controller: _host, hint: 'Host or IP, e.g. 192.168.1.20', onSubmitted: (_) => _save()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: context.type.bodySmall!.copyWith(color: context.colors.error)),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () async {
              await ref.read(savedTargetsRepositoryProvider).delete(widget.existing!.id);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Alerts for a host
// ---------------------------------------------------------------------------

/// Quick alert rules for one host. Rules run on Monitor checks, so turning
/// one on also adds the host to Monitor.
Future<void> showHostAlertSheet(BuildContext context, PingSession session) =>
    _showSheet(context, (_) => _HostAlertSheet(session: session));

/// Whether any enabled alert rule watches [host].
final hostHasAlertProvider = Provider.family<bool, String>((ref, host) {
  final rules = ref.watch(alertRulesProvider).value ?? const <AlertRule>[];
  return rules.any((r) => r.enabled && r.target.toLowerCase() == host.toLowerCase());
});

class _HostAlertSheet extends ConsumerWidget {
  const _HostAlertSheet({required this.session});
  final PingSession session;

  static const _presets = <({String metric, double threshold, int seconds, String title, String sub})>[
    (metric: AlertMetric.loss, threshold: 5, seconds: 60, title: 'Packet loss', sub: 'Loss over 5% for 1 min'),
    (metric: AlertMetric.down, threshold: 0, seconds: 60, title: 'Host down', sub: 'No reply for 1 min'),
    (metric: AlertMetric.latency, threshold: 100, seconds: 30, title: 'High latency', sub: 'RTT over 100 ms for 30 s'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = session.host;
    final rules = (ref.watch(alertRulesProvider).value ?? const <AlertRule>[])
        .where((r) => r.target.toLowerCase() == host.toLowerCase())
        .toList();
    final repo = ref.read(alertRulesRepositoryProvider);
    AlertRule? ruleFor(String metric) => rules.where((r) => r.metric == metric).firstOrNull;
    final others = rules.where((r) => !_presets.any((p) => p.metric == r.metric)).toList();
    return _SheetFrame(
      title: 'Alerts',
      subtitle: session.title,
      footer: PulseButton(
        label: 'Manage alert rules',
        style: PulseButtonStyle.tonal,
        size: PulseButtonSize.large,
        expand: true,
        onPressed: () {
          Navigator.of(context).pop();
          context.push(Routes.alerts);
        },
      ),
      children: [
        PulseSegmentedList(
          animate: false,
          children: [
            for (final p in _presets)
              Builder(
                builder: (context) {
                  final rule = ruleFor(p.metric);
                  final on = rule?.enabled ?? false;
                  return PulseSwitchItem(
                    title: p.title,
                    subtitle: rule == null ? p.sub : ruleCondition(rule),
                    value: on,
                    onChanged: (v) async {
                      if (rule == null) {
                        await repo.save(
                          RuleDraft(
                            title: '${p.title} · ${session.title}',
                            target: host,
                            metric: p.metric,
                            threshold: p.threshold,
                            forSeconds: p.seconds,
                          ),
                        );
                      } else {
                        await repo.setEnabled(rule.id, v);
                      }
                    },
                  );
                },
              ),
            for (final r in others)
              PulseSwitchItem(
                title: r.title,
                subtitle: ruleCondition(r),
                value: r.enabled,
                onChanged: (v) => repo.setEnabled(r.id, v),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
          child: Text(
            'Alerts run on Monitor checks, so turning one on adds $host to Monitor. '
            'It keeps being checked in the background, even after you stop this ping.',
            style: context.type.bodySmall!.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
