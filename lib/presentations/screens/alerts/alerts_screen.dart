import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/pulse/pulse.dart';
import '../../../data/db/app_database.dart';
import '../../../providers/alerts_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/background/notifications.dart';
import '../../navigation/destinations.dart';
import '../monitor/monitor_widgets.dart';
import 'rule_editor.dart';

export 'rule_editor.dart' show RuleEditor;

/// Alerts: the rules that watch Monitor's checks (latency, loss, down, new LAN
/// device), mute controls, a test notification and what fired recently.
///
/// Phone: one column, "New rule" FAB, the editor opens as its own page.
/// Tablet: rules on the left, the editor in a card on the right.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  /// Tablet: the rule in the editor card (null id = new rule).
  RuleDraft? _editing;

  static const _splitFrom = 760.0;

  @override
  void initState() {
    super.initState();
    // Alerts are pointless without notification permission.
    PulseNotifications.requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(alertRulesProvider);
    final rules = async.value ?? const <AlertRule>[];
    final on = rules.where((r) => r.enabled).length;
    final subtitle = '${rules.length} rule${rules.length == 1 ? '' : 's'} · $on on';

    return LayoutBuilder(
      builder: (context, box) {
        final split = !context.isCompact && box.maxWidth >= _splitFrom;
        final draft = _editing ?? (rules.isEmpty ? const RuleDraft() : RuleDraft.of(rules.first));

        void edit(AlertRule? r) {
          if (split) {
            setState(() => _editing = r == null ? const RuleDraft() : RuleDraft.of(r));
          } else {
            context.push(r == null ? Routes.alertRule : '${Routes.alertRule}?id=${r.id}');
          }
        }

        final list = _AlertsList(
          rules: rules,
          loading: async.isLoading && !async.hasValue,
          error: async.hasError ? '${async.error}' : null,
          selectedId: split ? draft.id : null,
          onEdit: edit,
          padded: !split,
        );

        if (!split) {
          return PulsePage(
            title: 'Alerts',
            subtitle: subtitle,
            backTo: Routes.monitor,
            actions: [
              if (!context.isCompact)
                PulseButton(label: 'New rule', icon: PulseIcons.plus, onPressed: () => edit(null)),
            ],
            fab: context.isCompact
                ? PulseFab(label: 'New rule', icon: PulseIcons.plus, onPressed: () => edit(null))
                : null,
            body: list,
          );
        }
        return PulsePage(
          title: 'Alerts',
          subtitle: subtitle,
          backTo: Routes.monitor,
          actions: [PulseButton(label: 'New rule', icon: PulseIcons.plus, onPressed: () => edit(null))],
          body: Padding(
            padding: const EdgeInsets.fromLTRB(PulseLayout.tabletPadding, 0, PulseLayout.tabletPadding, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: list),
                const SizedBox(width: 16),
                SizedBox(
                  width: box.maxWidth >= 1000 ? 400 : 360,
                  child: PulseEntrance(
                    index: 1,
                    child: PulseCard(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              RuleBadge(metric: draft.metric),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    draft.id == null ? 'New rule' : 'Edit rule',
                                    style: context.type.titleLarge,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: RuleEditor(
                              key: ValueKey(draft.id ?? 'new'),
                              draft: draft,
                              onDone: () => setState(() => _editing = null),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The scrolling column: firing banner, rules, mute, notifications, fired.
class _AlertsList extends ConsumerWidget {
  const _AlertsList({
    required this.rules,
    required this.loading,
    required this.error,
    required this.selectedId,
    required this.onEdit,
    required this.padded,
  });

  final List<AlertRule> rules;
  final bool loading;
  final String? error;
  final int? selectedId;
  final void Function(AlertRule? rule) onEdit;

  /// Single-column page (phones, tablets beside the Tools pane) pads itself;
  /// the split layout already pads both columns.
  final bool padded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final compact = context.isCompact;
    final events = ref.watch(alertEventsProvider).value ?? const <FiredAlert>[];
    final active = ref.watch(activeAlertProvider);
    final repo = ref.read(alertRulesRepositoryProvider);
    final settings = ref.watch(settingsProvider);
    final pad = padded ? context.pagePadding : 0.0;

    Widget spaced(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w);

    final children = <Widget>[
      if (active != null) spaced(_FiringBanner(alert: active, onDismiss: () => repo.dismiss(active.event.id))),
      if (!settings.notificationsEnabled)
        spaced(
          PulseCard(
            color: c.surfaceContainerHigh,
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                PulseIcon(PulseIcons.bell, size: 22, color: c.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Notifications are off in Settings, so rules only log to the list below.',
                    style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant),
                  ),
                ),
                PulseButton(
                  label: 'Turn on',
                  style: PulseButtonStyle.text,
                  size: PulseButtonSize.small,
                  onPressed: () =>
                      ref.read(settingsProvider.notifier).update((s) => s.copyWith(notificationsEnabled: true)),
                ),
              ],
            ),
          ),
        ),
      if (error != null)
        spaced(
          PulseErrorBanner(
            title: 'Couldn\'t read alert rules',
            message: error,
            onRetry: () => ref.invalidate(alertRulesProvider),
          ),
        ),
      const PulseSectionLabel('Rules', padding: EdgeInsets.fromLTRB(4, 4, 0, 8)),
      if (loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: PulseWavyBar(value: .4, semanticLabel: 'Loading rules'),
        )
      else if (rules.isEmpty)
        PulseCard(
          child: PulseEmptyState(
            title: 'No alert rules',
            message: 'Get told when a target is down, slow or losing packets.',
            icon: PulseIcons.bell,
            size: 96,
            action: compact
                ? null
                : PulseButton(label: 'New rule', icon: PulseIcons.plus, onPressed: () => onEdit(null)),
          ),
        )
      else
        PulseSegmentedList(
          children: [
            for (final r in rules)
              _RuleTile(
                rule: r,
                selected: r.id == selectedId,
                onTap: () => onEdit(r),
                onToggle: (v) => repo.setEnabled(r.id, v),
              ),
          ],
        ),
      const PulseSectionLabel('Notifications'),
      const _MuteControls(),
      const SizedBox(height: 3),
      PulseListItem(
        title: 'Send a test notification',
        subtitle: 'Check that alerts reach this device',
        leading: PulseIcon(PulseIcons.bell, size: 22, color: c.onSurfaceVariant),
        trailing: const PulseIcon(PulseIcons.chevR, size: 20),
        onTap: () async {
          await PulseNotifications.requestPermission();
          await PulseNotifications.show(
            id: 0x7e57,
            title: 'Pulse test alert',
            body: 'Alerts from your rules arrive like this.',
            sound: settings.notificationSound,
          );
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Test notification sent')));
          }
        },
      ),
      const PulseSectionLabel('Recently fired'),
      if (events.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('Nothing has fired yet.', style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant)),
        )
      else
        PulseSegmentedList(
          children: [
            for (final e in events.take(8))
              PulseListItem(
                leading: RuleBadge(metric: e.rule.metric, muted: e.event.dismissed || !e.rule.firing),
                title: e.event.message,
                subtitle: '${whenLabel(e.event.at)} · ${e.rule.title}',
                minHeight: 60,
              ),
          ],
        ),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 4, pad, compact ? PulseLayout.fabClearance + 16 : 24),
      children: [for (var i = 0; i < children.length; i++) PulseEntrance(index: i, child: children[i])],
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule, required this.selected, required this.onTap, required this.onToggle});
  final AlertRule rule;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final r = rule;
    final status = r.firing
        ? 'Firing now'
        : r.lastFiredAt != null
        ? 'Fired ${whenLabel(r.lastFiredAt!).toLowerCase()}'
        : null;
    return MergeSemantics(
      child: PulseListItem(
        title: r.title,
        subtitle: '${ruleCondition(r)}\n${[channelsLabel(r.channels), ?status].join(' · ')}',
        subtitleMaxLines: 2,
        minHeight: 72,
        selected: selected,
        leading: RuleBadge(metric: r.metric, muted: !r.enabled),
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (r.firing) ...[const PulsePill('Firing', tone: PulsePillTone.pink, dot: true), const SizedBox(width: 8)],
            Switch(value: r.enabled, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}

/// Mute: off → chips for 1 h / 4 h / 8 h; on → "Muted until 15:04" + Unmute.
class _MuteControls extends ConsumerWidget {
  const _MuteControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final muted = ref.watch(alertsMutedUntilProvider);
    final n = ref.read(alertsMutedUntilProvider.notifier);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: muted == null ? c.surfaceContainer : c.secondaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24), bottom: Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PulseIcon(
                muted == null ? PulseIcons.bell : PulseIcons.pause,
                size: 22,
                color: muted == null ? c.onSurfaceVariant : c.onSecondaryContainer,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      muted == null ? 'Mute alerts' : 'Alerts muted',
                      style: context.type.titleMedium!.copyWith(
                        color: muted == null ? c.onSurface : c.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      muted == null
                          ? 'Checks keep running; notifications wait'
                          : 'Until ${DateFormat('HH:mm').format(muted)}${muted.day != DateTime.now().day ? ' tomorrow' : ''}',
                      style: context.type.bodySmall!.copyWith(
                        color: muted == null ? c.onSurfaceVariant : c.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              if (muted != null)
                PulseButton(
                  label: 'Unmute',
                  style: PulseButtonStyle.neutral,
                  size: PulseButtonSize.small,
                  onPressed: n.unmute,
                ),
            ],
          ),
          if (muted == null)
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (h, label) in const [(1, '1 h'), (4, '4 h'), (8, '8 h')])
                    // The row is titled "Mute alerts", so the chips only need
                    // the duration; "Mute 8 h" wrapped to a second line on phones.
                    PulseChip(
                      label: label,
                      small: true,
                      icon: PulseIcons.timer,
                      onTap: () => n.muteFor(Duration(hours: h)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A rule that is firing right now (attention = pink container), with Dismiss.
class _FiringBanner extends StatelessWidget {
  const _FiringBanner({required this.alert, required this.onDismiss});
  final FiredAlert alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
        decoration: BoxDecoration(color: c.primaryContainer, borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: [
            RuleBadge(metric: alert.rule.metric, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Firing since ${DateFormat('HH:mm').format(alert.event.at)}',
                    style: context.type.labelMedium!.copyWith(color: c.onPrimaryContainer),
                  ),
                  Text(alert.event.message, style: context.type.titleMedium!.copyWith(color: c.onPrimaryContainer)),
                  Text(
                    '${ruleCondition(alert.rule)} · still ongoing',
                    style: context.type.bodySmall!.copyWith(color: c.onPrimaryContainer),
                  ),
                ],
              ),
            ),
            PulseButton(
              label: 'Dismiss',
              style: PulseButtonStyle.text,
              size: PulseButtonSize.small,
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

/// Phones (and deep links): the rule editor as its own page.
class RuleEditorScreen extends ConsumerWidget {
  const RuleEditorScreen({super.key, this.ruleId});
  final int? ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(alertRulesProvider);
    final rules = async.value;
    final rule = ruleId == null ? null : rules?.where((r) => r.id == ruleId).firstOrNull;
    void done() => context.canPop() ? context.pop() : context.go(Routes.alerts);
    final waiting = ruleId != null && rules == null;
    return PulsePage(
      title: rule == null ? 'New rule' : 'Edit rule',
      backTo: Routes.alerts,
      body: waiting
          ? const Center(
              child: SizedBox(width: 200, child: PulseWavyBar(value: .4, semanticLabel: 'Loading rule')),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: RuleEditor(
                  key: ValueKey(rule?.id ?? 'new'),
                  compact: true,
                  draft: rule == null ? const RuleDraft() : RuleDraft.of(rule),
                  onDone: done,
                ),
              ),
            ),
    );
  }
}
