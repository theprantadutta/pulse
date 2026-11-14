import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/pulse/pulse.dart';
import '../../navigation/destinations.dart';
import 'settings_screen.dart' show kDeveloper, kPrivacyUrl, kTermsUrl, packageInfoProvider;
import 'settings_widgets.dart';

const kSourceUrl = 'https://github.com/theprantadutta/pulse_flutter_app';
const kLicenseName = 'Apache-2.0';

/// About Pulse: who makes it, the exact build, and the legal links.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageInfoProvider).value;
    final c = context.colors;
    final wide = !context.isCompact;
    final hero = _Hero(info: info);
    final developer = SettingsGroup(
      items: [
        (r) => SettingsValueItem(
          icon: PulseIcons.globe,
          title: kDeveloper.name,
          subtitle: kDeveloper.website.replaceFirst('https://', ''),
          chevron: true,
          onTap: () => _open(kDeveloper.website),
        ),
        (r) => SettingsValueItem(
          icon: PulseIcons.help,
          title: 'Contact us',
          subtitle: 'Questions, bugs or feedback',
          chevron: true,
          onTap: () => launchUrl(Uri(scheme: 'mailto', path: kDeveloper.email, query: 'subject=Pulse')),
        ),
        (r) => SettingsValueItem(
          icon: PulseIcons.code,
          title: 'Source code',
          subtitle: kSourceUrl.replaceFirst('https://', ''),
          chevron: true,
          onTap: () => _open(kSourceUrl),
        ),
      ],
    );
    final build = SettingsGroup(
      items: [
        (r) => SettingsValueItem(icon: PulseIcons.info, title: 'Version', value: info?.version ?? '—'),
        (r) => SettingsValueItem(icon: PulseIcons.data, title: 'Build number', value: info?.buildNumber ?? '—'),
        (r) => SettingsValueItem(icon: PulseIcons.code, title: 'Package', subtitle: info?.packageName ?? '—'),
        (r) => SettingsValueItem(icon: _platformIcon, title: 'Platform', subtitle: _platform),
        (r) => SettingsValueItem(icon: PulseIcons.code, title: 'Flutter', value: _flutterVersion),
        (r) => SettingsValueItem(icon: PulseIcons.pulse, title: 'Dart', value: _dartVersion),
      ],
    );
    final legal = SettingsGroup(
      items: [
        (r) => SettingsValueItem(
          icon: PulseIcons.shield,
          title: 'Privacy policy',
          subtitle: kPrivacyUrl.replaceFirst('https://', ''),
          chevron: true,
          onTap: () => _open(kPrivacyUrl),
        ),
        (r) => SettingsValueItem(
          icon: PulseIcons.info,
          title: 'Terms of use',
          subtitle: kTermsUrl.replaceFirst('https://', ''),
          chevron: true,
          onTap: () => _open(kTermsUrl),
        ),
        (r) => SettingsValueItem(
          icon: PulseIcons.data,
          title: 'Open-source licenses',
          subtitle: 'The packages Pulse is built with',
          chevron: true,
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Pulse',
            applicationVersion: info == null ? null : '${info.version} (${info.buildNumber})',
            applicationLegalese: _copyright,
          ),
        ),
      ],
    );
    final footer = Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 0),
      child: Text(
        '$_copyright\nReleased under the $kLicenseName license. No accounts, no analytics.',
        textAlign: TextAlign.center,
        style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant),
      ),
    );
    final copy = PulseButton(
      label: 'Copy app info',
      icon: PulseIcons.copy,
      style: PulseButtonStyle.tonal,
      onPressed: info == null ? null : () => _copyInfo(context, info),
    );

    final List<Widget> children;
    if (wide) {
      children = [
        hero,
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [const PulseSectionLabel('Made by'), developer, const PulseSectionLabel('Legal'), legal],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [const PulseSectionLabel('This build'), build],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(child: copy),
        footer,
      ];
    } else {
      children = [
        hero,
        const PulseSectionLabel('Made by'),
        developer,
        const PulseSectionLabel('This build'),
        build,
        const PulseSectionLabel('Legal'),
        legal,
        const SizedBox(height: 20),
        Center(child: copy),
        footer,
      ];
    }
    return PulsePage(title: 'About Pulse', backTo: Routes.settings, showBack: true, children: children);
  }

  static Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  static String get _copyright => '© ${DateTime.now().year} ${kDeveloper.name}';

  /// The flutter tool passes the SDK versions as compile-time defines.
  static const _flutterDefine = String.fromEnvironment('FLUTTER_VERSION');
  static const _dartDefine = String.fromEnvironment('FLUTTER_DART_VERSION');

  static String get _flutterVersion => _flutterDefine.isEmpty ? '—' : _flutterDefine;

  static String get _dartVersion => _dartDefine.isNotEmpty ? _dartDefine : Platform.version.split(' ').first;

  static PulseIcons get _platformIcon => Platform.isAndroid || Platform.isIOS ? PulseIcons.phone : PulseIcons.laptop;

  /// Dart reports the kernel on Android and iOS, so the version is only shown
  /// where it is the OS release (Windows, macOS, Linux).
  static String get _platform {
    final name = switch (Platform.operatingSystem) {
      'android' => 'Android',
      'ios' => 'iOS',
      'macos' => 'macOS',
      'windows' => 'Windows',
      'linux' => 'Linux',
      final other => other,
    };
    if (Platform.isAndroid || Platform.isIOS) return name;
    final version = Platform.operatingSystemVersion.replaceAll('"', '');
    if (Platform.isWindows) {
      // Windows 11 still reports itself as "Windows 10" to Dart; builds from
      // 22000 on are Windows 11.
      final build = int.tryParse(RegExp(r'Build (\d+)').firstMatch(version)?.group(1) ?? '');
      if (build != null) return 'Windows ${build >= 22000 ? 11 : 10} · build $build';
    }
    return '$name · $version';
  }

  static Future<void> _copyInfo(BuildContext context, PackageInfo info) async {
    final text = [
      'Pulse ${info.version} (build ${info.buildNumber})',
      'Package: ${info.packageName}',
      'Platform: $_platform',
      'Flutter: $_flutterVersion',
      'Dart: $_dartVersion',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      showPulseToast(context, 'App info copied', icon: PulseIcons.copy);
    }
  }
}

/// Logo, name, tagline and the version pill.
class _Hero extends StatelessWidget {
  const _Hero({required this.info});
  final PackageInfo? info;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final info = this.info;
    return Container(
      // The closing text button's tap area adds its own space below the label.
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
      decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(32)),
      child: Column(
        children: [
          const PulseLogo(size: 88, tile: true),
          const SizedBox(height: 16),
          Text('Pulse', style: context.type.headlineLarge),
          const SizedBox(height: 4),
          Text(
            'Network diagnostics for desktop and mobile',
            textAlign: TextAlign.center,
            style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              PulsePill(info == null ? 'Version —' : 'Version ${info.version}', tone: PulsePillTone.pink),
              if (info != null) PulsePill('Build ${info.buildNumber}'),
              const PulsePill(kLicenseName),
            ],
          ),
          const SizedBox(height: 8),
          const UpdateCheckButton(),
        ],
      ),
    );
  }
}
