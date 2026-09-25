import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/brand/pulse_mark.dart';
import '../../../core/widgets/wire/wire.dart';
import '../../../core/widgets/wire/wire_page.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/ping_models.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/network_provider.dart';
import '../../../providers/ping_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/background/background_service.dart';
import '../../../services/background/notifications.dart';
import '../../../services/desktop/desktop_host.dart';
import '../../../services/desktop/launch_at_login.dart';
import '../../../services/net/ping_prober.dart';
import '../../../services/update_checker.dart';
import '../tools/tool_widgets.dart';

enum SettingsSection {
  appearance('Appearance'),
  ping('Ping defaults'),
  monitor('Monitor'),
  notifications('Notifications'),
  data('Data & export'),
  privacy('Privacy'),
  about('About');

  const SettingsSection(this.label);
  final String label;
}

final _packageInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());

/// 14 — Settings.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SettingsSection _section = SettingsSection.appearance;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final version = ref.watch(_packageInfoProvider).value?.version ?? '';
    return WireAdaptive(
      mobile: (context) => WireMobilePage(
        header: WireMobileHeader(title: 'Settings', signal: true, onBack: mobileBack(context)),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            for (final s in SettingsSection.values) ...[
              WireSectionBar(s.label, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
              _SectionBody(section: s, dense: true),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Text('PULSE $version · APACHE-2.0', style: WireType.body(11).copyWith(color: w.text2)),
            ),
          ],
        ),
      ),
      desktop: (context) => WireDesktopPage(
        topBar: const WireTopTitle('Settings'),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 240,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final s in SettingsSection.values)
                    _SectionTab(label: s.label, selected: s == _section, onTap: () => setState(() => _section = s)),
                ],
              ),
            ),
            const WireVRule(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WireSectionBar(_section.label, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10)),
                  Expanded(child: SingleChildScrollView(child: _SectionBody(section: _section))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: w.ink, width: kWireBorder))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: 'PULSE $version', style: const TextStyle(fontWeight: FontWeight.w700)),
                                const TextSpan(text: ' · Apache-2.0 · made with Flutter'),
                              ],
                            ),
                            style: WireType.body(12),
                          ),
                        ),
                        const _UpdateCheck(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return WirePressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      builder: (context, c, st) => Container(
        constraints: const BoxConstraints(minHeight: WireLayout.minHit),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: c.bg,
          border: Border(bottom: BorderSide(color: w.ink, width: kWireHairline)),
        ),
        child: Text(label.toUpperCase(), style: WireType.data(13).copyWith(color: c.fg)),
      ),
    );
  }
}

class _SectionBody extends ConsumerWidget {
  const _SectionBody({required this.section, this.dense = false});
  final SettingsSection section;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final pad = EdgeInsets.symmetric(horizontal: dense ? 14 : 24, vertical: dense ? 11 : 14);
    final messenger = ScaffoldMessenger.of(context);
    Future<void> set(AppSettings Function(AppSettings) f) => n.update(f);

    switch (section) {
      case SettingsSection.appearance:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Block(
              pad: pad,
              title: 'Theme',
              child: dense
                  ? WireSegmented<ThemeMode>(
                      options: const [(ThemeMode.light, 'PAPER'), (ThemeMode.dark, 'INK'), (ThemeMode.system, 'SYSTEM')],
                      selected: s.themeMode,
                      onChanged: n.setThemeMode,
                    )
                  : Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final m in const [ThemeMode.light, ThemeMode.dark, ThemeMode.system])
                          _ThemeCard(mode: m, selected: s.themeMode == m, onTap: () => n.setThemeMode(m)),
                      ],
                    ),
            ),
            _Block(
              pad: pad,
              title: 'Accent',
              description: 'Used for live values, spikes and primary actions',
              inline: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in WireColors.accents.entries) ...[
                    _Swatch(color: e.value, name: e.key, size: dense ? 28 : 40, selected: s.accent == e.key, onTap: () => n.setAccent(e.key)),
                    SizedBox(width: dense ? 8 : 10),
                  ],
                ],
              ),
            ),
          ],
        );

      case SettingsSection.ping:
        Widget seg<T>(String title, List<(T, String)> opts, T value, ValueChanged<T> on, {bool enabled = true, String? desc}) =>
            _Block(pad: pad, title: title, description: desc, child: WireSegmented<T>(options: opts, selected: value, onChanged: on, enabled: enabled, height: 40));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            seg('Default count', [for (final c in PingParams.counts) (c, c == 0 ? '∞' : '$c')], s.pingCount, (v) => set((x) => x.copyWith(pingCount: v))),
            seg('Interval', [for (final v in PingParams.intervals) (v, '${v / 1000} S'.replaceAll('.0 ', ' '))], s.pingIntervalMs, (v) => set((x) => x.copyWith(pingIntervalMs: v))),
            seg('Timeout', [for (final v in PingParams.timeouts) (v, '$v S')], s.pingTimeoutSec, (v) => set((x) => x.copyWith(pingTimeoutSec: v))),
            seg(
              'Packet size',
              [for (final v in PingParams.sizes) (v, '$v B')],
              s.packetSize,
              (v) => set((x) => x.copyWith(packetSize: v)),
              enabled: PingProber.supportsPacketSize,
              desc: PingProber.supportsPacketSize ? null : 'iOS sends a fixed payload',
            ),
            seg(
              'IP version',
              const [(IpVersionPref.auto, 'AUTO'), (IpVersionPref.ipv4, 'IPv4'), (IpVersionPref.ipv6, 'IPv6'), (IpVersionPref.both, 'BOTH')],
              s.ipVersion,
              (v) => set((x) => x.copyWith(ipVersion: v)),
            ),
            seg(
              'Slow above',
              const [(30, '30 MS'), (60, '60 MS'), (100, '100 MS'), (150, '150 MS')],
              s.slowThresholdMs,
              (v) => set((x) => x.copyWith(slowThresholdMs: v)),
              desc: 'Replies slower than this are marked SLOW in signal',
            ),
          ],
        );

      case SettingsSection.monitor:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Block(
              pad: pad,
              title: 'Check every',
              child: WireSegmented<int>(
                height: 40,
                options: const [(30, '30 S'), (60, '1 MIN'), (300, '5 MIN'), (900, '15 MIN')],
                selected: s.monitorIntervalSec,
                onChanged: (v) => set((x) => x.copyWith(monitorIntervalSec: v)),
              ),
            ),
            if (BackgroundMonitor.supported)
              _ToggleRow(
                pad: pad,
                title: 'Run in background',
                description: Platform.isIOS
                    ? 'iOS lets Pulse check roughly every 15 minutes in the background'
                    : 'Keeps a small notification while Pulse checks your targets',
                value: s.monitorInBackground,
                onChanged: (v) async {
                  if (v) await BackgroundMonitor.requestPermissions();
                  await set((x) => x.copyWith(monitorInBackground: v));
                },
              ),
            if (DesktopHost.supported) ...[
              _ToggleRow(
                pad: pad,
                title: 'Keep running in tray',
                description: 'Closing the window keeps monitoring from the system tray',
                value: s.closeToTray,
                onChanged: (v) async {
                  await set((x) => x.copyWith(closeToTray: v));
                  await DesktopHost.instance.setCloseToTray(v);
                },
              ),
              _ToggleRow(
                pad: pad,
                title: 'Launch at login',
                description: 'Starts Pulse in the tray when you sign in',
                value: s.launchAtStartup,
                onChanged: (v) async {
                  try {
                    await LaunchAtLogin.setEnabled(v);
                    await set((x) => x.copyWith(launchAtStartup: v));
                  } on Object catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('Could not change login item: $e')));
                  }
                },
              ),
            ],
            if (!Platform.isIOS)
              _ToggleRow(
                pad: pad,
                title: 'Watch for new devices',
                description: 'Sweeps the LAN every 15 minutes and records new devices',
                value: s.lanDeviceWatch,
                onChanged: (v) => set((x) => x.copyWith(lanDeviceWatch: v)),
              ),
          ],
        );

      case SettingsSection.notifications:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ToggleRow(
              pad: pad,
              title: 'Notifications',
              description: 'Alert rules can notify you even when Pulse is in the background',
              value: s.notificationsEnabled,
              onChanged: (v) async {
                if (v && !await PulseNotifications.requestPermission() && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
                  messenger.showSnackBar(const SnackBar(content: Text('Notifications are blocked in system settings')));
                }
                await set((x) => x.copyWith(notificationsEnabled: v));
              },
            ),
            _ToggleRow(
              pad: pad,
              title: 'Sound',
              description: 'Play a sound for rules that have SOUND on',
              value: s.notificationSound,
              onChanged: (v) => set((x) => x.copyWith(notificationSound: v)),
            ),
            _ValueRow(
              pad: pad,
              title: 'Send a test',
              description: 'Checks that alerts reach you',
              value: 'TEST',
              dense: dense,
              onTap: () => PulseNotifications.show(id: 9, title: 'Pulse', body: 'Notifications work.', sound: s.notificationSound),
            ),
          ],
        );

      case SettingsSection.data:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ValueRow(
              pad: pad,
              title: 'Keep history',
              description: 'Older sessions are removed automatically',
              value: '${s.retentionDays} DAYS',
              dense: dense,
              onTap: () async {
                const steps = [30, 90, 180, 365];
                final next = steps[(steps.indexOf(s.retentionDays) + 1) % steps.length];
                await set((x) => x.copyWith(retentionDays: next));
                await ref.read(databaseProvider).applyRetention(next);
              },
            ),
            _ValueRow(
              pad: pad,
              title: 'Export format',
              description: 'Used by every Export button',
              value: s.exportFormat.name.toUpperCase(),
              dense: dense,
              onTap: () => set((x) => x.copyWith(exportFormat: x.exportFormat == ExportFormat.csv ? ExportFormat.txt : ExportFormat.csv)),
            ),
            if (DesktopHost.supported)
              _ValueRow(
                pad: pad,
                title: 'Export folder',
                description: 'Where exports are saved; unset asks every time',
                value: s.exportFolder ?? 'ASK',
                dense: dense,
                onTap: () async {
                  final dir = await FilePicker.getDirectoryPath(dialogTitle: 'Pulse export folder');
                  if (dir != null) await set((x) => x.copyWith(exportFolder: dir));
                },
              ),
            _ValueRow(
              pad: pad,
              title: 'Clear all data',
              description: 'Deletes history, rules, targets and devices',
              value: 'CLEAR',
              dense: dense,
              danger: true,
              onTap: () async {
                final ok = await _confirm(context, 'Clear all data?', 'History, saved targets, monitor targets, alert rules and LAN devices are deleted. Settings are kept.');
                if (!ok) return;
                await ref.read(pingBoardProvider.notifier).stopAll();
                ref.read(pingBoardProvider.notifier).clearFinished();
                await ref.read(databaseProvider).clearAll();
                messenger.showSnackBar(const SnackBar(content: Text('All data cleared')));
              },
            ),
          ],
        );

      case SettingsSection.privacy:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ToggleRow(
              pad: pad,
              title: 'Public IP lookups',
              description: 'Sends IPs to ip-api.com / ipinfo.io for ISP, ASN and location (Network, Geo IP, Traceroute)',
              value: s.publicIpLookups,
              onChanged: (v) async {
                await set((x) => x.copyWith(publicIpLookups: v));
                ref.read(networkInfoProvider.notifier).refresh();
              },
            ),
            Padding(
              padding: pad,
              child: Text(
                'Everything else stays on this device. Pulse also talks to: Cloudflare and Hetzner (speed test), '
                'OpenStreetMap (map tiles), api6.ipify.org (IPv6 check) and GitHub (update check). '
                'No accounts, no analytics.',
                style: WireType.body(12).copyWith(color: context.wire.text2),
              ),
            ),
          ],
        );

      case SettingsSection.about:
        final info = ref.watch(_packageInfoProvider).value;
        return Padding(
          padding: pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PulseLockup(height: dense ? 36 : 56, colorway: Theme.of(context).brightness == Brightness.dark ? PulseMarkColorway.dark : PulseMarkColorway.paper),
              const SizedBox(height: 16),
              Text('Version ${info?.version ?? ''} (${info?.buildNumber ?? ''})', style: WireType.data(13)),
              const SizedBox(height: 4),
              Text('Network diagnostics for desktop and mobile. Apache-2.0.', style: WireType.body(12).copyWith(color: context.wire.text2)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  WireButton(label: 'GitHub', height: 40, fontSize: 15, onPressed: () => launchUrl(Uri.parse('https://github.com/${UpdateChecker.repo}'))),
                  WireButton(
                    label: 'Licenses',
                    height: 40,
                    fontSize: 15,
                    onPressed: () => showLicensePage(context: context, applicationName: 'Pulse', applicationVersion: info?.version),
                  ),
                  const _UpdateCheck(asButton: true),
                ],
              ),
            ],
          ),
        );
    }
  }
}

Future<bool> _confirm(BuildContext context, String title, String body) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (context) {
      final w = context.wire;
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: w.signal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Text(title.toUpperCase(), style: WireType.title(26).copyWith(color: w.onSignal)),
              ),
              Padding(padding: const EdgeInsets.all(20), child: Text(body, style: WireType.body(13))),
              PanelActions(
                actions: [
                  (label: 'Cancel', primary: false, onTap: () => Navigator.of(context).pop(false)),
                  (label: 'Clear', primary: true, onTap: () => Navigator.of(context).pop(true)),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return r ?? false;
}

class _Block extends StatelessWidget {
  const _Block({required this.pad, required this.title, required this.child, this.description, this.inline = false});
  final EdgeInsets pad;
  final String title;
  final String? description;
  final Widget child;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: WireType.title(pad.left > 20 ? 22 : 19)),
        if (description != null) Text(description!, style: WireType.body(12).copyWith(color: w.text2, height: 1.3)),
      ],
    );
    return Container(
      padding: pad,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: w.ink, width: kWireBorder))),
      child: inline
          ? Row(children: [Expanded(child: head), const SizedBox(width: 12), child])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, const SizedBox(height: 12), child]),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.pad, required this.title, required this.value, required this.onChanged, this.description});
  final EdgeInsets pad;
  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return WireRow(
      onTap: () => onChanged(!value),
      padding: pad.copyWith(top: pad.top - 4, bottom: pad.bottom - 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: WireType.title(pad.left > 20 ? 20 : 19)),
                if (description != null) Text(description!, style: WireType.body(12).copyWith(color: w.text2, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          WireToggle(value: value, onChanged: onChanged, semanticLabel: title),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.pad,
    required this.title,
    required this.value,
    required this.onTap,
    this.description,
    this.dense = false,
    this.danger = false,
  });

  final EdgeInsets pad;
  final String title;
  final String? description;
  final String value;
  final VoidCallback onTap;
  final bool dense;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return WireRow(
      onTap: onTap,
      padding: pad,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: WireType.title(dense ? 19 : 20)),
                if (description != null && !dense) Text(description!, style: WireType.body(12).copyWith(color: w.text2, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (dense)
            Text(value, style: WireType.data(12).copyWith(color: danger ? w.signal : w.signal))
          else
            Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: danger ? w.signalTint : null,
                border: Border.all(color: w.ink, width: kWireBorder),
              ),
              child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: WireType.data(13)),
            ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.mode, required this.selected, required this.onTap});
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    Widget preview(WireColors c) => Container(
      color: c.background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 40, decoration: BoxDecoration(color: c.signal, border: Border(right: BorderSide(color: c.ink, width: kWireBorder)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            child: Text('25', style: WireType.hero(40).copyWith(color: c.ink)),
          ),
        ],
      ),
    );
    final label = switch (mode) {
      ThemeMode.light => 'PAPER',
      ThemeMode.dark => 'INK',
      ThemeMode.system => 'SYSTEM',
    };
    return WirePressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, c, s) => Container(
        width: 200,
        decoration: BoxDecoration(
          color: w.background,
          border: Border.all(color: w.ink, width: kWireBorder),
          boxShadow: selected ? [BoxShadow(color: w.signal, offset: const Offset(5, 5), blurRadius: 0)] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 90,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: w.ink, width: kWireBorder))),
              child: switch (mode) {
                ThemeMode.light => preview(WireColors.light),
                ThemeMode.dark => preview(WireColors.dark),
                ThemeMode.system => Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: Container(decoration: BoxDecoration(color: WireColors.paper, border: Border(right: BorderSide(color: w.ink, width: kWireBorder))))),
                    Expanded(child: Container(color: WireColors.inkBlack)),
                  ],
                ),
              },
            ),
            Container(
              color: s.contains(WidgetState.hovered) ? w.signalTint : null,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text('${selected ? '✓ ' : ''}$label', style: WireType.label(12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.name, required this.size, required this.selected, required this.onTap});
  final Color color;
  final String name;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return WirePressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: '$name accent',
      tooltip: name,
      builder: (context, c, s) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: w.ink, width: kWireBorder),
            boxShadow: selected ? [BoxShadow(color: w.ink, offset: const Offset(4, 4), blurRadius: 0)] : null,
          ),
        ),
      ),
    );
  }
}

class _UpdateCheck extends ConsumerStatefulWidget {
  const _UpdateCheck({this.asButton = false});
  final bool asButton;

  @override
  ConsumerState<_UpdateCheck> createState() => _UpdateCheckState();
}

class _UpdateCheckState extends ConsumerState<_UpdateCheck> {
  String? _status;
  UpdateInfo? _info;
  bool _busy = false;

  Future<void> _check() async {
    if (_info?.newer == true) {
      await launchUrl(Uri.parse(_info!.url));
      return;
    }
    setState(() => _busy = true);
    try {
      final current = (await PackageInfo.fromPlatform()).version;
      final info = await const UpdateChecker().check(current);
      setState(() {
        _info = info;
        _status = info.newer ? 'v${info.latest} AVAILABLE →' : 'UP TO DATE';
      });
    } on Object {
      setState(() => _status = 'CHECK FAILED');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _busy ? 'CHECKING…' : _status ?? 'CHECK FOR UPDATES';
    if (widget.asButton) {
      return WireButton(label: label, height: 40, fontSize: 15, onPressed: _busy ? null : _check);
    }
    return WirePressable(
      onTap: _busy ? null : _check,
      semanticLabel: label,
      builder: (context, c, s) => Container(
        color: c.bg,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(label, style: WireType.label(12).copyWith(color: _info?.newer == true ? context.wire.signal : c.fg)),
      ),
    );
  }
}
