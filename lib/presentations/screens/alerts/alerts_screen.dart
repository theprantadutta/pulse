import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/wire/wire.dart';
import '../../../core/widgets/wire/wire_page.dart';
import '../../../data/db/app_database.dart';
import '../../../providers/alerts_provider.dart';
import '../../../services/background/notifications.dart';
import '../../navigation/destinations.dart';
import '../tools/tool_widgets.dart';
import 'rule_editor.dart';

/// 13 — Alerts.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  RuleDraft? _editing;

  @override
  void initState() {
    super.initState();
    // Alerts are pointless without notification permission.
    PulseNotifications.requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final rules = ref.watch(alertRulesProvider).value ?? const <AlertRule>[];
    final events = ref.watch(alertEventsProvider).value ?? const <FiredAlert>[];
    final active = ref.watch(activeAlertProvider);
    final muted = ref.watch(alertsMutedUntilProvider);
    final repo = ref.read(alertRulesRepositoryProvider);
    final draft = _editing ?? (rules.isEmpty ? const RuleDraft() : RuleDraft.of(rules.first));

    Widget ruleRow(AlertRule r, {bool dense = false}) => WireRow(
      selected: !dense && draft.id == r.id,
      highlight: r.firing ? WireRowHighlight.tint : WireRowHighlight.none,
      divider: dense ? kWireHairline : kWireBorder,
      onTap: () => dense ? context.push('${Routes.alertRule}?id=${r.id}') : setState(() => _editing = RuleDraft.of(r)),
      padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 20, vertical: dense ? 10 : 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title.toUpperCase(), style: WireType.display(dense ? 20 : 24, width: 72, height: 1)),
                const SizedBox(height: 3),
                Text(ruleCondition(r), style: WireType.body(dense ? 11 : 12).copyWith(height: 1.3)),
                if (!dense)
                  Text(
                    [
                      channelLabel(r.channels),
                      if (r.firing) 'FIRING NOW' else if (r.lastFiredAt != null) 'FIRED ${fmtWhen(r.lastFiredAt!)}',
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: WireType.label().copyWith(color: w.text2),
                  ),
              ],
            ),
          ),
          WireToggle(value: r.enabled, onChanged: (v) => repo.setEnabled(r.id, v), semanticLabel: r.title),
        ],
      ),
    );

    Widget fired({bool dense = false}) => events.isEmpty
        ? Padding(
            padding: EdgeInsets.all(dense ? 14 : 20),
            child: Text('Nothing has fired yet.', style: WireType.body(12).copyWith(color: w.text3)),
          )
        : Column(
            children: [
              for (final e in events.take(dense ? 4 : 6))
                WireRow(
                  padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 20, vertical: 8),
                  child: dense
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fmtWhen(e.event.at), style: WireType.data(11)),
                            Text(e.event.message, style: WireType.body(11).copyWith(height: 1.3)),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 120, child: Text(fmtWhen(e.event.at), style: WireType.data(12))),
                            Expanded(child: Text(e.event.message, style: WireType.body(12).copyWith(height: 1.3))),
                          ],
                        ),
                ),
            ],
          );

    final mutedLabel = muted == null ? 'MUTE 1H' : 'MUTED TO ${DateFormat('HH:mm').format(muted)}';
    void toggleMute() {
      final n = ref.read(alertsMutedUntilProvider.notifier);
      muted == null ? n.muteFor(const Duration(hours: 1)) : n.unmute();
    }

    return WireAdaptive(
      mobile: (context) => WireMobilePage(
        header: WireMobileHeader(
          title: 'Alerts',
          onBack: mobileBack(context),
          trailing: WirePressable(
            onTap: () => context.push(Routes.alertRule),
            tone: WireTone.ink,
            semanticLabel: 'New rule',
            builder: (context, c, s) => Container(
              color: c.bg,
              height: WireLayout.mobileHeader,
              alignment: Alignment.center,
              child: Text('+ NEW', style: WireType.label(12).copyWith(color: s.isEmpty ? w.signal : c.fg)),
            ),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (active != null) _Banner(alert: active, onDismiss: () => repo.dismiss(active.event.id)),
            if (rules.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: WireEmptyState(
                  title: 'No rules',
                  message: 'Get told when a target is down, slow or losing packets.',
                  compact: true,
                ),
              ),
            for (final r in rules) ruleRow(r, dense: true),
            WireRow(
              onTap: toggleMute,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(mutedLabel, style: WireType.label()),
            ),
            const WireSectionBar('Recently fired', padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
            fired(dense: true),
          ],
        ),
      ),
      desktop: (context) => WireDesktopPage(
        panelWidth: 420,
        topBar: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: WireTopTitle(
                'Alerts',
                subtitle:
                    '${rules.length} RULE${rules.length == 1 ? '' : 'S'} · ${rules.where((r) => r.enabled).length} ACTIVE',
              ),
            ),
            const WireVRule(),
            WireTopChip(label: mutedLabel, selected: muted != null, onTap: toggleMute),
            WireButton(
              label: 'New rule',
              glyph: '+',
              variant: WireButtonVariant.primary,
              bordered: false,
              fontSize: 17,
              height: WireLayout.topBar,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              onPressed: () => setState(() => _editing = const RuleDraft()),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (active != null) _Banner(alert: active, onDismiss: () => repo.dismiss(active.event.id)),
            const WireSectionBar('Rules'),
            Expanded(
              child: rules.isEmpty
                  ? const WireEmptyState(
                      title: 'No rules',
                      message: 'Create one on the right — Pulse watches in the background and tells you.',
                    )
                  : ListView(children: [for (final r in rules) ruleRow(r)]),
            ),
            const WireSectionBar('Recently fired'),
            fired(),
          ],
        ),
        panel: RuleEditor(
          key: ValueKey(draft.id ?? 'new'),
          draft: draft,
          onDone: () => setState(() => _editing = null),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.alert, required this.onDismiss});
  final FiredAlert alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Container(
      color: w.signal,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '▲ FIRED ${DateFormat('HH:mm').format(alert.event.at)}',
                  style: WireType.label().copyWith(color: w.onSignal),
                ),
                Text(alert.event.message.toUpperCase(), style: WireType.stat(28).copyWith(color: w.onSignal)),
                Text(
                  '${ruleCondition(alert.rule)} · still ongoing',
                  style: WireType.body(12).copyWith(color: w.onSignal),
                ),
              ],
            ),
          ),
          WirePressable(
            onTap: onDismiss,
            tone: WireTone.signal,
            semanticLabel: 'Dismiss',
            builder: (context, c, s) => Container(
              color: c.bg,
              constraints: const BoxConstraints(minHeight: WireLayout.minHit),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              child: Text('DISMISS', style: WireType.label().copyWith(color: c.fg)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mobile: the rule editor as a pushed screen.
class RuleEditorScreen extends ConsumerWidget {
  const RuleEditorScreen({super.key, this.ruleId});
  final int? ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(alertRulesProvider).value ?? const <AlertRule>[];
    final rule = ruleId == null ? null : rules.where((r) => r.id == ruleId).firstOrNull;
    return WireMobilePage(
      header: WireMobileHeader(title: rule == null ? 'New rule' : 'Edit rule', onBack: mobileBack(context)),
      body: RuleEditor(
        compact: true,
        draft: rule == null ? const RuleDraft() : RuleDraft.of(rule),
        onDone: () => context.canPop() ? context.pop() : context.go(Routes.alerts),
      ),
    );
  }
}
