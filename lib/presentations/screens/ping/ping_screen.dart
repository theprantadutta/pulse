import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/wire/wire.dart';
import '../../../core/widgets/wire/wire_page.dart';
import '../../../providers/ping_provider.dart';
import '../../../providers/settings_provider.dart';
import 'ping_configure.dart';
import 'ping_widgets.dart';

/// 01 Ping / Live, 02 Configure and the multi-ping board.
class PingScreen extends ConsumerStatefulWidget {
  const PingScreen({super.key});

  @override
  ConsumerState<PingScreen> createState() => _PingScreenState();
}

class _PingScreenState extends ConsumerState<PingScreen> {
  final _target = TextEditingController();
  final _name = TextEditingController();
  final _targetFocus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _editing = ref.read(pingBoardProvider).sessions.isEmpty;
    final d = ref.read(pingDraftProvider);
    _target.text = d.host;
    _name.text = d.name;
  }

  @override
  void dispose() {
    _target.dispose();
    _name.dispose();
    _targetFocus.dispose();
    super.dispose();
  }

  void _pick(String host, String? name) {
    _target.text = host;
    _name.text = name ?? '';
    ref.read(pingDraftProvider.notifier)
      ..setHost(host)
      ..setName(name ?? '');
    setState(() {});
  }

  Future<void> _start() async {
    final host = _target.text.trim();
    if (host.isEmpty) {
      _targetFocus.requestFocus();
      return;
    }
    final id = await ref
        .read(pingBoardProvider.notifier)
        .start(host, name: _name.text, params: ref.read(pingDraftProvider).params);
    if (!mounted) return;
    if (id == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('At most $kMaxLivePings live pings at once — stop one first.')));
      return;
    }
    _name.clear();
    ref.read(pingDraftProvider.notifier).setName('');
    setState(() => _editing = false);
  }

  void _edit({PingSession? from}) {
    if (from != null) {
      _target.text = from.host;
      _name.text = from.name ?? '';
      ref.read(pingDraftProvider.notifier)
        ..setHost(from.host)
        ..setName(from.name ?? '');
    }
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _targetFocus.requestFocus());
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(pingBoardProvider);
    if (board.sessions.isEmpty && !_editing) _editing = true;
    return WireAdaptive(
      mobile: (context) => _PingMobile(state: this),
      desktop: (context) {
        if (_editing) return _configureDesktop(board);
        if (board.showBoard && board.sessions.length > 1) return _boardDesktop(board);
        return _liveDesktop(board);
      },
    );
  }

  // ---------------------------------------------------------------- desktop

  Widget _configureDesktop(PingBoard board) {
    final w = context.wire;
    return WireDesktopPage(
      panelWidth: 380,
      topBar: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: WireTargetField(
              controller: _target,
              focusNode: _targetFocus,
              editing: true,
              onChanged: (v) => setState(() => ref.read(pingDraftProvider.notifier).setHost(v)),
              onSubmitted: (_) => _start(),
            ),
          ),
          const WireVRule(),
          Expanded(
            flex: 2,
            child: WireTargetField(
              controller: _name,
              prefix: 'NAME>',
              hint: 'optional, e.g. Office PC',
              fontSize: 15,
              onChanged: (v) => ref.read(pingDraftProvider.notifier).setName(v),
              onSubmitted: (_) => _start(),
            ),
          ),
          const WireVRule(),
          if (board.sessions.isNotEmpty)
            WireButton(
              label: 'Cancel',
              bordered: false,
              sides: WireSides.onlyRight,
              fontSize: 16,
              height: WireLayout.topBar,
              onPressed: () => setState(() => _editing = false),
            ),
          WireButton(
            label: 'Start',
            glyph: '▶',
            variant: WireButtonVariant.primary,
            bordered: false,
            height: WireLayout.topBar,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            onPressed: _start,
          ),
        ],
      ),
      body: Container(
        color: w.background,
        child: PingConfigureMain(onPicked: _pick, onStarted: () => setState(() => _editing = false)),
      ),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: w.ink, width: kWireBorder),
              ),
            ),
            child: Text('PARAMETERS', style: WireType.title(26)),
          ),
          const Expanded(child: SingleChildScrollView(child: PingParametersPanel())),
          const SaveAsDefaultRow(),
        ],
      ),
    );
  }

  Widget _liveDesktop(PingBoard board) {
    final w = context.wire;
    final s = board.focused!;
    final notifier = ref.read(pingBoardProvider.notifier);
    final slow = ref.watch(settingsProvider.select((x) => x.slowThresholdMs)).toDouble();
    final hero = heroValue(s);
    return WireDesktopPage(
      topBar: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: WireCell(
              onTap: () => _edit(from: s),
              sides: WireSides.onlyRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              semanticLabel: 'Edit target',
              child: Row(
                children: [
                  Text('TARGET>', style: WireType.label(12)),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(s.host, maxLines: 1, overflow: TextOverflow.ellipsis, style: WireType.data(20)),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      [if (s.name != null) s.name!.toUpperCase(), ?s.describe].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WireType.body(13).copyWith(color: w.text3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          WireTopChip(
            label: 'COUNT ${s.params.countLabel}',
            onTap: () => _edit(from: s),
          ),
          WireTopChip(
            label: 'INT ${(s.params.intervalMs / 1000).toStringAsFixed(1)}s',
            onTap: () => _edit(from: s),
          ),
          WireTopChip(
            label: 'T/O ${s.params.timeoutSec}s',
            onTap: () => _edit(from: s),
          ),
          WireTopChip(label: '+ NEW', onTap: () => _edit()),
          if (s.running)
            WireButton(
              label: 'Stop',
              glyph: '■',
              variant: WireButtonVariant.inverse,
              bordered: false,
              height: WireLayout.topBar,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              onPressed: () => notifier.stop(s.id),
            )
          else
            WireButton(
              label: 'Start',
              glyph: '▶',
              variant: WireButtonVariant.primary,
              bordered: false,
              height: WireLayout.topBar,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              onPressed: () => notifier.restart(s.id),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (board.sessions.length > 1) const PingSessionStrip(),
          SizedBox(
            height: 232,
            child: s.unreachable
                ? Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: w.ink, width: kWireBorder),
                      ),
                    ),
                    child: WireErrorBlock(
                      reason: s.error ?? 'Every recent probe to ${s.host} came back unreachable.',
                      size: 120,
                      onRetry: () => notifier.restart(s.id),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: w.ink, width: kWireBorder),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 316,
                          padding: const EdgeInsets.fromLTRB(32, 20, 24, 12),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: w.ink, width: kWireBorder),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.running ? 'RTT / NOW' : 'RTT / LAST', style: WireType.label(12)),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomLeft,
                                  child: WireHeroNumber(value: hero.value, unit: hero.unit, size: 180),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: w.ink, width: kWireBorder),
                                  ),
                                ),
                                child: PingStatStrip(session: s),
                              ),
                              Expanded(
                                child: WireBarChart.latency(values: chartValues(s, 30), threshold: slow, slots: 30),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: PingReplyLog(session: s)),
                const WireVRule(),
                Expanded(
                  flex: 2,
                  child: PingRecentTargets(
                    onPick: (host, name) => ref
                        .read(pingBoardProvider.notifier)
                        .start(host, name: name, params: ref.read(pingDraftProvider).params),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _boardDesktop(PingBoard board) {
    final notifier = ref.read(pingBoardProvider.notifier);
    final done = board.sessions.length - board.liveCount;
    return WireDesktopPage(
      topBar: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: WireTopTitle('All pings', subtitle: '${board.liveCount} LIVE · ${board.sessions.length} TOTAL'),
          ),
          const WireVRule(),
          WireTopChip(label: '+ NEW PING', onTap: () => _edit()),
          if (done > 0) WireTopChip(label: 'CLEAR $done DONE', onTap: notifier.clearFinished),
          WireButton(
            label: 'Stop all',
            glyph: '■',
            variant: WireButtonVariant.inverse,
            bordered: false,
            height: WireLayout.topBar,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            onPressed: board.liveCount == 0 ? null : notifier.stopAll,
          ),
        ],
      ),
      body: const PingBoardGrid(),
    );
  }
}

// ------------------------------------------------------------------ mobile

class _PingMobile extends ConsumerWidget {
  const _PingMobile({required this.state});
  final _PingScreenState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(pingBoardProvider);
    final notifier = ref.read(pingBoardProvider.notifier);
    if (board.sessions.isEmpty) return _MobileStart(state: state);
    if (board.showBoard && board.sessions.length > 1) {
      return WireMobilePage(
        header: WireMobileHeader(
          title: 'Ping',
          signal: board.liveCount > 0,
          trailing: Text(board.liveCount > 0 ? '● ${board.liveCount} LIVE' : '${board.sessions.length} DONE'),
        ),
        body: const PingBoardGrid(cellWidth: 400),
        action: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: WireButton.bar(
                  label: 'New',
                  glyph: '+',
                  variant: WireButtonVariant.outline,
                  sides: WireSides.onlyRight,
                  onPressed: () => showPingConfigSheet(context),
                ),
              ),
              Expanded(
                child: WireButton.bar(
                  label: 'Stop all',
                  glyph: '■',
                  variant: WireButtonVariant.inverse,
                  onPressed: board.liveCount == 0 ? null : notifier.stopAll,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _MobileLive(session: board.focused!, multi: board.sessions.length > 1);
  }
}

class _MobileStart extends ConsumerWidget {
  const _MobileStart({required this.state});
  final _PingScreenState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    return WireMobilePage(
      header: const WireMobileHeader(title: 'Ping', signal: true, trailing: Text('IDLE')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 52,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: w.ink, width: kWireBorder),
              ),
            ),
            child: WireTargetField(
              controller: state._target,
              focusNode: state._targetFocus,
              fontSize: 18,
              editing: true,
              onChanged: (v) => ref.read(pingDraftProvider.notifier).setHost(v),
              onSubmitted: (_) => state._start(),
              trailing: _ConfigLink(onTap: () => showPingConfigSheet(context)),
            ),
          ),
          Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: w.ink, width: kWireBorder),
              ),
            ),
            child: WireTargetField(
              controller: state._name,
              prefix: 'NAME>',
              hint: 'optional',
              fontSize: 15,
              onChanged: (v) => ref.read(pingDraftProvider.notifier).setName(v),
            ),
          ),
          PingConfigureMain(embedded: true, onPicked: state._pick, onStarted: () {}),
        ],
      ),
      action: WireButton.bar(label: 'Start ping', glyph: '▶', onPressed: state._start),
    );
  }
}

class _ConfigLink extends StatelessWidget {
  const _ConfigLink({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WirePressable(
      onTap: onTap,
      semanticLabel: 'Configure',
      builder: (context, c, s) => Container(
        color: c.bg,
        constraints: const BoxConstraints(minHeight: WireLayout.minHit, minWidth: WireLayout.minHit),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text('CONFIG', style: WireType.label().copyWith(color: c.fg)),
      ),
    );
  }
}

class _MobileLive extends ConsumerWidget {
  const _MobileLive({required this.session, required this.multi});
  final PingSession session;
  final bool multi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final s = session;
    final notifier = ref.read(pingBoardProvider.notifier);
    final slow = ref.watch(settingsProvider.select((x) => x.slowThresholdMs)).toDouble();
    final hero = heroValue(s);
    final st = s.stats;
    return WireMobilePage(
      header: WireMobileHeader(
        title: multi ? s.title : 'Ping',
        signal: true,
        onBack: multi ? () => notifier.showBoard(true) : null,
        trailing: Text(sessionStatus(s)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: w.ink, width: kWireBorder),
              ),
            ),
            child: Row(
              children: [
                Text('TARGET>', style: WireType.label()),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(s.host, maxLines: 1, overflow: TextOverflow.ellipsis, style: WireType.data(18)),
                ),
                _ConfigLink(onTap: () => showPingConfigSheet(context, from: s)),
                const SizedBox(width: 10),
              ],
            ),
          ),
          if (s.unreachable)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: w.ink, width: kWireBorder),
                ),
              ),
              child: WireErrorBlock(
                reason: s.error ?? 'Every recent probe came back unreachable.',
                size: 64,
                onRetry: () => notifier.restart(s.id),
              ),
            )
          else
            Container(
              height: 180,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              alignment: Alignment.bottomLeft,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: w.ink, width: kWireBorder),
                ),
              ),
              child: WireHeroNumber(value: hero.value, unit: hero.unit, size: 170),
            ),
          Container(
            height: 100,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: w.ink, width: kWireBorder),
              ),
            ),
            child: WireBarChart.latency(
              values: chartValues(s, 20),
              threshold: slow,
              slots: 20,
              gridStep: 25,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: w.ink, width: kWireBorder),
              ),
            ),
            child: WireSplitRow(
              children: [
                WireStat(
                  label: 'Avg',
                  value: fmtMs(st.avg),
                  valueSize: 32,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                ),
                WireStat(
                  label: 'Loss',
                  value: fmtPct(st.lossPct),
                  valueSize: 32,
                  tone: st.lost > 0 ? WireTone.tint : WireTone.plain,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: w.ink, width: kWireBorder),
              ),
            ),
            child: WireSplitRow(
              children: [
                WireStat(
                  label: 'Max',
                  value: fmtMs(st.max),
                  valueSize: 32,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                ),
                WireStat(
                  label: 'Jitter',
                  value: fmtMs(st.jitter),
                  valueSize: 32,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
      action: s.running
          ? WireButton.bar(
              label: 'Stop',
              glyph: '■',
              variant: WireButtonVariant.inverse,
              onPressed: () => notifier.stop(s.id),
            )
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: WireButton.bar(
                      label: 'New',
                      glyph: '+',
                      variant: WireButtonVariant.outline,
                      sides: WireSides.onlyRight,
                      onPressed: () => showPingConfigSheet(context),
                    ),
                  ),
                  Expanded(
                    child: WireButton.bar(label: 'Again', glyph: '▶', onPressed: () => notifier.restart(s.id)),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Mobile CONFIGURE bottom sheet: target, name, parameters, saved targets
/// and a signal ▶ START PING bar.
Future<void> showPingConfigSheet(BuildContext context, {PingSession? from}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: kWireSheetAnimation,
    useSafeArea: true,
    barrierColor: context.wire.filtered.withValues(alpha: 0.7),
    builder: (context) => _ConfigSheet(from: from),
  );
}

class _ConfigSheet extends ConsumerStatefulWidget {
  const _ConfigSheet({this.from});
  final PingSession? from;

  @override
  ConsumerState<_ConfigSheet> createState() => _ConfigSheetState();
}

class _ConfigSheetState extends ConsumerState<_ConfigSheet> {
  late final _target = TextEditingController(text: widget.from?.host ?? ref.read(pingDraftProvider).host);
  late final _name = TextEditingController(text: widget.from?.name ?? ref.read(pingDraftProvider).name);

  @override
  void dispose() {
    _target.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final host = _target.text.trim();
    if (host.isEmpty) return;
    final id = await ref
        .read(pingBoardProvider.notifier)
        .start(host, name: _name.text, params: ref.read(pingDraftProvider).params);
    if (!mounted) return;
    if (id == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('At most $kMaxLivePings live pings at once — stop one first.')));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 44, height: 4, color: w.ink),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 0, 6, 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: w.ink, width: kWireBorder),
                ),
              ),
              child: Row(
                children: [
                  Expanded(child: Text('CONFIGURE', style: WireType.title(28))),
                  WirePressable(
                    onTap: () => ref.read(pingDraftProvider.notifier).reset(),
                    semanticLabel: 'Reset',
                    builder: (context, c, s) => Container(
                      color: c.bg,
                      constraints: const BoxConstraints(minHeight: WireLayout.minHit),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('RESET', style: WireType.label(12).copyWith(color: c.fg)),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: w.ink, width: kWireBorder),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('TARGET', style: WireType.label()),
                        const SizedBox(height: 6),
                        WireInput(
                          controller: _target,
                          hint: '1.1.1.1',
                          keyboardType: TextInputType.url,
                          autofocus: widget.from == null,
                          onSubmitted: (_) => _start(),
                        ),
                        const SizedBox(height: 12),
                        Text('NAME', style: WireType.label()),
                        const SizedBox(height: 6),
                        WireInput(controller: _name, hint: 'optional, e.g. Library PC'),
                      ],
                    ),
                  ),
                  const PingParametersPanel(showIpVersion: true, compact: true),
                  PingConfigureMain(
                    embedded: true,
                    onPicked: (host, name) {
                      _target.text = host;
                      _name.text = name ?? '';
                    },
                    onStarted: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: WireButton(
                label: 'Start ping',
                glyph: '▶',
                variant: WireButtonVariant.primary,
                height: WireLayout.actionBar,
                fontSize: 20,
                expand: true,
                onPressed: _start,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
