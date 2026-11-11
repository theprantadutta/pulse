import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/pulse/pulse.dart';
import '../../../data/db/app_database.dart';
import '../../../providers/alerts_provider.dart';
import '../../../providers/monitor_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/background/background_service.dart';
import '../../navigation/destinations.dart';
import 'monitor_widgets.dart';

final _hostPattern = RegExp(r'^[A-Za-z0-9.\-:%_]+$');

Future<T?> _sheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: builder(context),
  ),
);

/// Sheet title row: headlineSmall title + optional subtitle.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, this.subtitle, this.leading});
  final String title;
  final String? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 14)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.type.headlineSmall),
              ),
              if (subtitle != null)
                Text(subtitle!, style: context.type.bodySmall!.copyWith(color: context.colors.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Add target
// ---------------------------------------------------------------------------

/// Adds a monitored host (re-enables it if it already exists).
Future<void> showAddTargetSheet(BuildContext context) => _sheet<void>(context, (_) => const _AddTargetSheet());

class _AddTargetSheet extends ConsumerStatefulWidget {
  const _AddTargetSheet();

  @override
  ConsumerState<_AddTargetSheet> createState() => _AddTargetSheetState();
}

class _AddTargetSheetState extends ConsumerState<_AddTargetSheet> {
  final _host = TextEditingController();
  final _name = TextEditingController();
  String? _error;
  bool _saving = false;

  static const _suggestions = [('1.1.1.1', 'Cloudflare'), ('8.8.8.8', 'Google DNS'), ('github.com', 'GitHub')];

  @override
  void dispose() {
    _host.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final h = _host.text.trim();
    if (h.isEmpty) {
      setState(() => _error = 'Enter a host name or IP address.');
      return;
    }
    if (!_hostPattern.hasMatch(h)) {
      setState(() => _error = 'That doesn\'t look like a host name or IP address.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(monitorTargetsRepositoryProvider).add(h, _name.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't add the target: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final interval = ref.watch(settingsProvider.select((s) => s.monitorIntervalSec));
    final background = ref.watch(settingsProvider.select((s) => s.monitorInBackground));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader(
            title: 'Add target',
            subtitle: 'Pulse checks it ${monitorCadence(interval, background: background)}.',
            leading: const PulseShapeBadge(shape: PulseShape.diamond, tone: PulseTone.lavender, icon: PulseIcons.plus),
          ),
          PulseTargetField(
            controller: _host,
            hint: 'Host or IP, e.g. 8.8.8.8',
            autofocus: true,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Text(_error!, style: context.type.bodySmall!.copyWith(color: c.error)),
            ),
          const SizedBox(height: 10),
          PulseTargetField(
            controller: _name,
            hint: 'Name (optional)',
            icon: PulseIcons.pin,
            keyboardType: TextInputType.text,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          PulseChipRow(
            children: [
              for (final (host, name) in _suggestions)
                PulseChip(
                  label: name,
                  small: true,
                  icon: PulseIcons.plus,
                  onTap: () => setState(() {
                    _host.text = host;
                    _name.text = name;
                    _error = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PulseButton(label: 'Cancel', style: PulseButtonStyle.text, onPressed: () => Navigator.of(context).pop()),
              const SizedBox(width: 8),
              PulseButton(label: 'Add target', icon: PulseIcons.plus, onPressed: _saving ? null : _save),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Target details
// ---------------------------------------------------------------------------

/// Details for one target: uptime, latest latency, the full uptime strip,
/// its incidents, rename, watch on/off and remove.
Future<void> showTargetSheet(BuildContext context, MonitorTarget target) =>
    _sheet<void>(context, (_) => _TargetSheet(targetId: target.id, initial: target));

class _TargetSheet extends ConsumerStatefulWidget {
  const _TargetSheet({required this.targetId, required this.initial});
  final int targetId;
  final MonitorTarget initial;

  @override
  ConsumerState<_TargetSheet> createState() => _TargetSheetState();
}

class _TargetSheetState extends ConsumerState<_TargetSheet> {
  late final _name = TextEditingController(text: widget.initial.name);
  bool _dirty = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _remove(MonitorTarget t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${t.host}?'),
        content: const Text('Its check history and incidents are deleted too. Alert rules for it stay.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(monitorTargetsRepositoryProvider).delete(t.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final overview = ref.watch(monitorOverviewProvider).value;
    final range = ref.watch(monitorRangeProvider);
    final row = overview?.rows.where((r) => r.target.id == widget.targetId).firstOrNull;
    final t = row?.target ?? widget.initial;
    final incidents = (ref.watch(incidentsProvider).value ?? const <IncidentView>[])
        .where((i) => i.incident.targetId == t.id)
        .take(4)
        .toList();
    final repo = ref.read(monitorTargetsRepositoryProvider);
    final now = row == null
        ? const PulseStat('Now', '—')
        : row.nowDown
        ? const PulseStat('Now', 'No reply')
        : PulseStat('Now', msLabel(row.nowMs), unit: row.nowMs == null ? null : 'ms');
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader(
            title: t.host,
            subtitle: t.name.isEmpty ? null : t.name,
            leading: const PulseShapeBadge(
              shape: PulseShape.diamond,
              tone: PulseTone.lavender,
              icon: PulseIcons.monitor,
            ),
          ),
          PulseStatRow(
            stats: [
              PulseStat(
                'Uptime ${rangeTitle(range)}',
                pctLabel(row?.uptime),
                color: row?.uptime == null ? null : (row!.uptime! >= 99.5 ? c.tertiary : null),
              ),
              now,
              PulseStat(
                'Status',
                !t.enabled
                    ? 'Paused'
                    : (row?.incident ?? false)
                    ? 'Incident'
                    : 'Watching',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Last ${rangeLabel(range)}', style: context.type.labelMedium!.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: 6),
          UptimeStrip(blocks: row?.blocks ?? const [], count: 48, height: 28),
          const SizedBox(height: 8),
          const UptimeLegend(),
          const PulseSectionLabel('Name'),
          Row(
            children: [
              Expanded(
                child: PulseTargetField(
                  controller: _name,
                  hint: 'Name',
                  icon: PulseIcons.pin,
                  keyboardType: TextInputType.text,
                  onChanged: (v) => setState(() => _dirty = v.trim() != t.name),
                  onSubmitted: (v) async {
                    await repo.update(t.id, name: v.trim());
                    if (mounted) setState(() => _dirty = false);
                  },
                ),
              ),
              const SizedBox(width: 8),
              PulseButton(
                label: 'Save',
                style: PulseButtonStyle.tonal,
                onPressed: _dirty
                    ? () async {
                        await repo.update(t.id, name: _name.text.trim());
                        if (mounted) setState(() => _dirty = false);
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          PulseSwitchItem(
            title: 'Watch this target',
            subtitle: t.enabled ? 'Checked on every monitoring cycle' : 'Paused: not checked, history kept',
            value: t.enabled,
            onChanged: (v) => repo.update(t.id, enabled: v),
          ),
          if (incidents.isNotEmpty) ...[
            const PulseSectionLabel('Incidents'),
            PulseSegmentedList(
              animate: false,
              children: [for (final i in incidents) IncidentTile(view: i, host: t.host)],
            ),
          ],
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: PulseButton(
              label: 'Remove target',
              icon: PulseIcons.trash,
              style: PulseButtonStyle.outlined,
              onPressed: () => _remove(t),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Monitoring options
// ---------------------------------------------------------------------------

/// Check now, check interval, run in background, last cycle, alerts.
Future<void> showMonitorOptionsSheet(BuildContext context) => _sheet<void>(context, (_) => const _OptionsSheet());

class _OptionsSheet extends ConsumerWidget {
  const _OptionsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final run = ref.watch(monitorRunnerProvider);
    final runner = ref.read(monitorRunnerProvider.notifier);
    final s = ref.watch(settingsProvider);
    final muted = ref.watch(alertsMutedUntilProvider);
    final last = run.last;
    final paused = run.mode == MonitorMode.paused;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader(
            title: 'Monitoring',
            subtitle: last == null
                ? 'No check has run yet'
                : 'Last check ${whenLabel(last.at)} · ${last.targets} checked, ${last.down} down',
          ),
          Row(
            children: [
              Expanded(
                child: PulseButton(
                  label: run.cycling ? 'Checking…' : 'Check now',
                  icon: PulseIcons.refresh,
                  style: PulseButtonStyle.tonal,
                  expand: true,
                  onPressed: run.cycling || run.mode == MonitorMode.service || paused ? null : runner.runNow,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PulseButton(
                  label: paused ? 'Resume' : 'Pause',
                  icon: paused ? PulseIcons.play : PulseIcons.pause,
                  style: PulseButtonStyle.neutral,
                  expand: true,
                  onPressed: runner.togglePaused,
                ),
              ),
            ],
          ),
          if (run.mode == MonitorMode.service)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'The background service runs the checks on its own schedule.',
                style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant),
              ),
            ),
          const PulseSectionLabel('Check every'),
          PulseButtonGroup<int>(
            segments: [for (final v in kMonitorIntervals) PulseSegment(v, intervalLabel(v))],
            selected: s.monitorIntervalSec,
            onChanged: (v) => ref.read(settingsProvider.notifier).update((x) => x.copyWith(monitorIntervalSec: v)),
          ),
          const SizedBox(height: 16),
          PulseSegmentedList(
            animate: false,
            children: [
              if (BackgroundMonitor.supported)
                PulseSwitchItem(
                  title: 'Run in background',
                  subtitle: Platform.isIOS
                      ? 'iOS lets Pulse check roughly every 15 minutes in the background'
                      : 'Keeps a small notification while Pulse checks your targets',
                  value: s.monitorInBackground,
                  onChanged: (v) async {
                    if (v) await BackgroundMonitor.requestPermissions();
                    await ref.read(settingsProvider.notifier).update((x) => x.copyWith(monitorInBackground: v));
                  },
                ),
              PulseSwitchItem(
                title: 'Mute alerts for 1 hour',
                subtitle: muted == null
                    ? 'Checks keep running; notifications wait'
                    : 'Muted until ${DateFormat('HH:mm').format(muted)}',
                value: muted != null,
                onChanged: (v) {
                  final n = ref.read(alertsMutedUntilProvider.notifier);
                  v ? n.muteFor(const Duration(hours: 1)) : n.unmute();
                },
              ),
              PulseListItem(
                title: 'Alert rules',
                subtitle: 'Get told when a target is down, slow or losing packets',
                leading: PulseIcon(PulseIcons.bell, size: 22, color: c.onSurfaceVariant),
                trailing: const PulseIcon(PulseIcons.chevR, size: 20),
                onTap: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.go(Routes.alerts);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
