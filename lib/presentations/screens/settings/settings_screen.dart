import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/pulse/pulse.dart';
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
import '../../navigation/destinations.dart';
import 'settings_widgets.dart';

const kPrivacyUrl = 'https://legal.pranta.dev/pulse/privacy';
const kTermsUrl = 'https://legal.pranta.dev/pulse/terms';
const kDeveloper = (name: 'Pranta Dutta', email: 'prantadutta1997@gmail.com');

enum SettingsSection {
  appearance('Appearance', PulseIcons.palette),
  ping('Ping defaults', PulseIcons.pulse),
  monitor('Monitor', PulseIcons.monitor, phoneLabelOverride: 'Monitor & alerts'),
  notifications('Notifications', PulseIcons.bell),
  desktop('Desktop', PulseIcons.laptop),
  data('Data & export', PulseIcons.data),
  privacy('Privacy', PulseIcons.shield),
  about('About', PulseIcons.info);

  const SettingsSection(this.label, this.icon, {this.phoneLabelOverride});
  final String label;
  final PulseIcons icon;
  final String? phoneLabelOverride;
  String get phoneLabel => phoneLabelOverride ?? label;

  /// Desktop settings (tray, launch at login) only exist on desktop.
  static List<SettingsSection> get available => [
    for (final s in values)
      if (s != desktop || DesktopHost.supported) s,
  ];
}

final packageInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());

/// Whether the platform can hand us wallpaper / accent colours (Android 12+,
/// or a desktop accent colour). Without it the Dynamic color switch explains
/// why it is unavailable.
final dynamicColorSupportProvider = FutureProvider<bool>((ref) async {
  try {
    if (Platform.isAndroid) return await DynamicColorPlugin.getCorePalette() != null;
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return await DynamicColorPlugin.getAccentColor() != null;
    }
  } on Object {
    return false;
  }
  return false;
});

/// 14 Settings.
///
/// * Phone / medium: one scrolling column with primary section labels.
/// * Expanded (>= 840): a 300 dp categories pane next to the selected section.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.initialSection = SettingsSection.appearance});

  final SettingsSection initialSection;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late SettingsSection _section = widget.initialSection;

  @override
  Widget build(BuildContext context) {
    if (!context.isExpanded) {
      return PulsePage(
        title: 'Settings',
        backTo: Routes.tools,
        children: [
          for (final s in SettingsSection.available) ...[
            PulseSectionLabel(
              s.phoneLabel,
              primary: true,
              padding: EdgeInsets.fromLTRB(8, s == SettingsSection.appearance ? 4 : 18, 0, 8),
            ),
            SettingsSectionBody(section: s),
          ],
        ],
      );
    }
    final c = context.colors;
    final sections = SettingsSection.available;
    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PulsePane(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const PulsePaneHeader(title: 'Settings'),
                  for (var i = 0; i < sections.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: PulseEntrance(
                        index: i,
                        fromLeft: true,
                        offset: 10,
                        child: SettingsCategoryItem(
                          label: sections[i].label,
                          icon: sections[i].icon,
                          selected: sections[i] == _section,
                          onTap: () => setState(() => _section = sections[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey(_section),
                child: _Detail(section: _section),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tablet detail: section headline, its rows, and (Appearance) the About footer.
class _Detail extends StatelessWidget {
  const _Detail({required this.section});
  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, PulseLayout.tabletPadding, 0),
          sliver: SliverList.list(
            children: [
              Semantics(header: true, child: Text(section.label, style: context.type.headlineLarge)),
              const SizedBox(height: 16),
              PulseEntrance(child: SettingsSectionBody(section: section, wide: true)),
            ],
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, PulseLayout.tabletPadding, 20),
            child: section == SettingsSection.appearance
                ? const Align(alignment: Alignment.bottomCenter, child: AboutCard())
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

/// The rows of one settings section. [wide] is the tablet detail variant
/// (theme preview cards, accent inline, longer descriptions).
class SettingsSectionBody extends ConsumerWidget {
  const SettingsSectionBody({super.key, required this.section, this.wide = false});
  final SettingsSection section;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    Future<void> set(AppSettings Function(AppSettings) f) => n.update(f);
    void snack(String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

    switch (section) {
      case SettingsSection.appearance:
        final dynamicOk = ref.watch(dynamicColorSupportProvider).value ?? false;
        final dynamicTile = PulseSwitchItem(
          icon: PulseIcons.auto,
          title: 'Dynamic color',
          subtitle: dynamicOk || s.dynamicColor
              ? (wide
                    ? 'Use colors from your wallpaper (Android 12+). Turns off the accent below.'
                    : 'Use wallpaper colors (Android 12+)')
              : 'Not available on this device',
          value: s.dynamicColor,
          onChanged: dynamicOk || s.dynamicColor ? (v) => set((x) => x.copyWith(dynamicColor: v)) : null,
        );
        final accent = AccentPicker(selected: s.accent, enabled: !s.dynamicColor, onChanged: (k) => n.setAccent(k));
        final motion = PulseSwitchItem(
          icon: PulseIcons.motion,
          title: 'Expressive motion',
          subtitle: wide
              ? 'Spring physics, shape morphs and live-ticking numbers. Off follows the system\'s reduce-motion setting.'
              : 'Springs and shape morphs',
          value: s.expressiveMotion,
          onChanged: (v) => set((x) => x.copyWith(expressiveMotion: v)),
        );
        if (wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Theme', style: context.type.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ThemePreviewRow(selected: s.themeMode, onChanged: n.setThemeMode),
              const SizedBox(height: 16),
              PulseSegmentedList(
                children: [
                  dynamicTile,
                  PulseListItem(
                    minHeight: 96,
                    leading: PulseIcon(PulseIcons.palette, size: 24, color: context.colors.onSurfaceVariant),
                    title: 'Accent',
                    subtitle: s.dynamicColor
                        ? 'Off while Dynamic color is on'
                        : 'Used for hero shapes, live values and primary actions',
                    subtitleMaxLines: 2,
                    trailing: accent,
                  ),
                  motion,
                ],
              ),
            ],
          );
        }
        return SettingsGroup(
          items: [
            (r) => ThemeGroupItem(radius: r, selected: s.themeMode, onChanged: n.setThemeMode),
            (r) => dynamicTile,
            (r) => AccentItem(radius: r, picker: accent, dimmed: s.dynamicColor),
            (r) => motion,
          ],
        );

      case SettingsSection.ping:
        String interval(int ms) => '${ms / 1000} s'.replaceAll('.0 ', ' ');
        return SettingsGroup(
          items: [
            (r) => SettingsValueItem(
              icon: PulseIcons.timer,
              title: 'Interval',
              value: interval(s.pingIntervalMs),
              onTap: () async {
                final v = await pickSetting(
                  context,
                  title: 'Ping interval',
                  message: 'Time between packets for new pings.',
                  options: [for (final v in PingParams.intervals) (v, interval(v))],
                  current: s.pingIntervalMs,
                );
                if (v != null) await set((x) => x.copyWith(pingIntervalMs: v));
              },
            ),
            (r) => SettingsValueItem(
              icon: PulseIcons.data,
              title: 'Packet size',
              subtitle: PingProber.supportsPacketSize ? null : 'iOS sends a fixed payload',
              value: '${s.packetSize} bytes',
              onTap: PingProber.supportsPacketSize
                  ? () async {
                      final v = await pickSetting(
                        context,
                        title: 'Packet size',
                        message: 'ICMP payload size. 1472 bytes fills a standard 1500 byte frame.',
                        options: [for (final v in PingParams.sizes) (v, '$v bytes')],
                        current: s.packetSize,
                      );
                      if (v != null) await set((x) => x.copyWith(packetSize: v));
                    }
                  : null,
            ),
            (r) => SettingsValueItem(
              icon: PulseIcons.clock,
              title: 'Timeout',
              value: '${s.pingTimeoutSec} s',
              onTap: () async {
                final v = await pickSetting(
                  context,
                  title: 'Timeout',
                  message: 'How long to wait for a reply before counting it as lost.',
                  options: [for (final v in PingParams.timeouts) (v, '$v s')],
                  current: s.pingTimeoutSec,
                );
                if (v != null) await set((x) => x.copyWith(pingTimeoutSec: v));
              },
            ),
            (r) => SettingsValueItem(
              icon: PulseIcons.refresh,
              title: 'Count',
              value: s.pingCount == 0 ? 'Continuous' : '${s.pingCount} pings',
              onTap: () async {
                final v = await pickSetting(
                  context,
                  title: 'Ping count',
                  message: 'How many packets a new ping sends before it stops.',
                  options: [for (final v in PingParams.counts) (v, v == 0 ? 'Continuous' : '$v pings')],
                  current: s.pingCount,
                );
                if (v != null) await set((x) => x.copyWith(pingCount: v));
              },
            ),
            (r) => SettingsValueItem(
              icon: PulseIcons.globe,
              title: 'IP version',
              value: _ipLabel(s.ipVersion),
              onTap: () async {
                final v = await pickSetting(
                  context,
                  title: 'IP version',
                  message: 'Both pings the IPv4 and IPv6 address side by side.',
                  options: [for (final v in IpVersionPref.values) (v, _ipLabel(v))],
                  current: s.ipVersion,
                );
                if (v != null) await set((x) => x.copyWith(ipVersion: v));
              },
            ),
            (r) => SettingsValueItem(
              icon: PulseIcons.gauge,
              title: 'Slow above',
              subtitle: wide ? 'Replies slower than this count as slow in alerts and summaries' : null,
              value: '${s.slowThresholdMs} ms',
              onTap: () async {
                final v = await pickSetting(
                  context,
                  title: 'Slow above',
                  message: 'Replies slower than this count as slow.',
                  options: [
                    for (final v in const [30, 60, 100, 150]) (v, '$v ms'),
                  ],
                  current: s.slowThresholdMs,
                );
                if (v != null) await set((x) => x.copyWith(slowThresholdMs: v));
              },
            ),
          ],
        );

      case SettingsSection.monitor:
        return SettingsGroup(
          items: [
            (r) => PulseSwitchItem(
              icon: PulseIcons.bell,
              title: 'Notify on outage',
              subtitle: 'Alert rules notify you, even when Pulse is in the background',
              value: s.notificationsEnabled,
              onChanged: (v) async {
                if (v &&
                    !await PulseNotifications.requestPermission() &&
                    (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
                  snack('Notifications are blocked in system settings');
                }
                await set((x) => x.copyWith(notificationsEnabled: v));
              },
            ),
            (r) => SettingsValueItem(
              icon: PulseIcons.tune,
              title: 'Alert rules',
              subtitle: 'Loss, latency and outage thresholds per target',
              onTap: () => context.go(Routes.alerts),
              chevron: true,
            ),
            (r) => SettingsValueItem(
              icon: PulseIcons.timer,
              title: 'Check every',
              value: _monitorLabel(s.monitorIntervalSec),
              onTap: () async {
                final v = await pickSetting(
                  context,
                  title: 'Check every',
                  message: 'How often Monitor checks each target.',
                  options: [
                    for (final v in const [30, 60, 300, 900]) (v, _monitorLabel(v)),
                  ],
                  current: s.monitorIntervalSec,
                );
                if (v != null) await set((x) => x.copyWith(monitorIntervalSec: v));
              },
            ),
            if (BackgroundMonitor.supported)
              (r) => PulseSwitchItem(
                icon: PulseIcons.play,
                title: 'Run in background',
                subtitle: Platform.isIOS
                    ? 'iOS lets Pulse check roughly every 15 minutes in the background'
                    : 'Keeps a small notification while Pulse checks your targets',
                value: s.monitorInBackground,
                onChanged: (v) async {
                  if (v) await BackgroundMonitor.requestPermissions();
                  await set((x) => x.copyWith(monitorInBackground: v));
                },
              ),
            if (!Platform.isIOS)
              (r) => PulseSwitchItem(
                icon: PulseIcons.lan,
                title: 'Watch for new devices',
                subtitle: 'Sweeps the LAN every 15 minutes and records new devices',
                value: s.lanDeviceWatch,
                onChanged: (v) => set((x) => x.copyWith(lanDeviceWatch: v)),
              ),
          ],
        );

      case SettingsSection.notifications:
        return SettingsGroup(
          items: [
            if (wide)
              (r) => PulseSwitchItem(
                icon: PulseIcons.bell,
                title: 'Notifications',
                subtitle: 'Same as Monitor › Notify on outage',
                value: s.notificationsEnabled,
                onChanged: (v) async {
                  if (v &&
                      !await PulseNotifications.requestPermission() &&
                      (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
                    snack('Notifications are blocked in system settings');
                  }
                  await set((x) => x.copyWith(notificationsEnabled: v));
                },
              ),
            (r) => PulseSwitchItem(
              icon: PulseIcons.signal,
              title: 'Sound',
              subtitle: 'Play a sound for rules that have sound on',
              value: s.notificationSound,
              onChanged: (v) => set((x) => x.copyWith(notificationSound: v)),
            ),
            (r) => SettingsValueItem(
              icon: PulseIcons.play,
              title: 'Send a test notification',
              subtitle: 'Checks that alerts reach you',
              value: 'Send',
              onTap: s.notificationsEnabled
                  ? () => PulseNotifications.show(
                      id: 9,
                      title: 'Pulse',
                      body: 'Notifications work.',
                      sound: s.notificationSound,
                    )
                  : null,
            ),
          ],
        );

      case SettingsSection.desktop:
        return SettingsGroup(
          items: [
            (r) => PulseSwitchItem(
              icon: PulseIcons.monitor,
              title: 'Keep running in tray',
              subtitle: 'Closing the window keeps monitoring from the system tray',
              value: s.closeToTray,
              onChanged: (v) async {
                await set((x) => x.copyWith(closeToTray: v));
                DesktopHost.instance.setCloseToTray(v);
              },
            ),
            (r) => PulseSwitchItem(
              icon: PulseIcons.power,
              title: 'Launch at login',
              subtitle: 'Starts Pulse in the tray when you sign in',
              value: s.launchAtStartup,
              onChanged: (v) async {
                try {
                  await LaunchAtLogin.setEnabled(v);
                  await set((x) => x.copyWith(launchAtStartup: v));
                } on LaunchAtLoginBlocked catch (e) {
                  snack(e.message);
                } on Object catch (e) {
                  snack('Could not change the login item: $e');
                }
              },
            ),
          ],
        );

      case SettingsSection.data:
        return SettingsGroup(
          items: [
            (r) => SettingsValueItem(
              icon: PulseIcons.clock,
              title: 'Keep history',
              subtitle: wide ? 'Older runs are removed automatically' : null,
              value: '${s.retentionDays} days',
              onTap: () async {
                final v = await pickSetting(
                  context,
                  title: 'Keep history',
                  message: 'Runs older than this are removed automatically.',
                  options: [
                    for (final v in const [30, 90, 180, 365]) (v, '$v days'),
                  ],
                  current: s.retentionDays,
                );
                if (v == null) return;
                await set((x) => x.copyWith(retentionDays: v));
                await ref.read(databaseProvider).applyRetention(v);
              },
            ),
            (r) => SettingsValueItem(
              icon: PulseIcons.export,
              title: 'Export format',
              subtitle: wide ? 'Default for every Export button' : null,
              value: _formatLabel(s.exportFormat),
              onTap: () async {
                final v = await pickSetting(
                  context,
                  title: 'Export format',
                  message: 'CSV opens in spreadsheets; JSON keeps every sample of each run.',
                  options: [for (final v in ExportFormat.values) (v, _formatLabel(v))],
                  current: s.exportFormat,
                );
                if (v != null) await set((x) => x.copyWith(exportFormat: v));
              },
            ),
            if (DesktopHost.supported)
              (r) => SettingsValueItem(
                icon: PulseIcons.data,
                title: 'Export folder',
                subtitle: s.exportFolder ?? 'Asks where to save every time',
                value: s.exportFolder == null ? 'Choose' : 'Change',
                onTap: () async {
                  final dir = await FilePicker.getDirectoryPath(dialogTitle: 'Pulse export folder');
                  if (dir != null) await set((x) => x.copyWith(exportFolder: dir));
                },
              ),
            (r) => SettingsValueItem(
              icon: PulseIcons.trash,
              title: 'Clear history',
              subtitle: 'Deletes every run in History',
              destructive: true,
              onTap: () async {
                final ok = await confirmDestructive(
                  context,
                  title: 'Clear history?',
                  body: 'Every run in History is deleted. Monitor targets, alert rules and settings are kept.',
                  action: 'Clear history',
                );
                if (!ok) return;
                final db = ref.read(databaseProvider);
                await db.delete(db.sessions).go();
                snack('History cleared');
              },
            ),
            (r) => SettingsValueItem(
              icon: PulseIcons.trash,
              title: 'Clear all data',
              subtitle: 'History, rules, targets and devices',
              destructive: true,
              onTap: () async {
                final ok = await confirmDestructive(
                  context,
                  title: 'Clear all data?',
                  body:
                      'History, saved targets, monitor targets, alert rules and LAN devices are deleted. '
                      'Settings are kept.',
                  action: 'Clear all',
                );
                if (!ok) return;
                await ref.read(pingBoardProvider.notifier).stopAll();
                ref.read(pingBoardProvider.notifier).clearFinished();
                await ref.read(databaseProvider).clearAll();
                snack('All data cleared');
              },
            ),
          ],
        );

      case SettingsSection.privacy:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsGroup(
              items: [
                (r) => PulseSwitchItem(
                  icon: PulseIcons.globe,
                  title: 'Public IP lookups',
                  subtitle: 'Sends IPs to ip-api.com / ipinfo.io for ISP, ASN and location',
                  value: s.publicIpLookups,
                  onChanged: (v) async {
                    await set((x) => x.copyWith(publicIpLookups: v));
                    ref.read(networkInfoProvider.notifier).refresh();
                  },
                ),
                (r) => SettingsValueItem(
                  icon: PulseIcons.shield,
                  title: 'Privacy policy',
                  subtitle: 'legal.pranta.dev/pulse/privacy',
                  chevron: true,
                  onTap: () => launchUrl(Uri.parse(kPrivacyUrl)),
                ),
                (r) => SettingsValueItem(
                  icon: PulseIcons.info,
                  title: 'Terms of use',
                  subtitle: 'legal.pranta.dev/pulse/terms',
                  chevron: true,
                  onTap: () => launchUrl(Uri.parse(kTermsUrl)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Public IP lookups power Network, Geo IP and Traceroute locations. Everything else stays on this '
                'device. Pulse also talks to Cloudflare and Hetzner (speed test), OpenStreetMap (map tiles), '
                'api6.ipify.org (IPv6 check) and GitHub (update check). No accounts, no analytics.',
                style: context.type.bodySmall!.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
          ],
        );

      case SettingsSection.about:
        final info = ref.watch(packageInfoProvider).value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AboutCard(),
            const SizedBox(height: 3),
            SettingsGroup(
              items: [
                (r) => SettingsValueItem(
                  icon: PulseIcons.info,
                  title: 'Version',
                  subtitle: 'Network diagnostics for desktop and mobile',
                  value: info == null ? '' : '${info.version} (${info.buildNumber})',
                ),
                (r) => SettingsValueItem(
                  icon: PulseIcons.code,
                  title: 'Source code',
                  subtitle: 'github.com/theprantadutta/pulse',
                  chevron: true,
                  onTap: () => launchUrl(Uri.parse('https://github.com/theprantadutta/pulse')),
                ),
                (r) => SettingsValueItem(
                  icon: PulseIcons.help,
                  title: 'Made by ${kDeveloper.name}',
                  subtitle: kDeveloper.email,
                  chevron: true,
                  onTap: () => launchUrl(Uri(scheme: 'mailto', path: kDeveloper.email, query: 'subject=Pulse')),
                ),
                (r) => SettingsValueItem(
                  icon: PulseIcons.data,
                  title: 'Open-source licenses',
                  chevron: true,
                  onTap: () =>
                      showLicensePage(context: context, applicationName: 'Pulse', applicationVersion: info?.version),
                ),
              ],
            ),
          ],
        );
    }
  }
}

String _ipLabel(IpVersionPref v) => switch (v) {
  IpVersionPref.auto => 'Auto',
  IpVersionPref.ipv4 => 'IPv4',
  IpVersionPref.ipv6 => 'IPv6',
  IpVersionPref.both => 'Both',
};

String _monitorLabel(int sec) => sec < 60 ? '$sec s' : '${sec ~/ 60} min';

String _formatLabel(ExportFormat f) => switch (f) {
  ExportFormat.csv => 'CSV',
  ExportFormat.json => 'JSON',
  ExportFormat.txt => 'Plain text',
};
