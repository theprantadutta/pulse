import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/share_config.dart';
import '../../../core/share/pulse_share.dart';
import '../../../core/widgets/pulse/pulse.dart';
import '../../navigation/destinations.dart';
import 'settings_screen.dart' show kDeveloper;
import 'settings_widgets.dart';

/// Settings › Support us: donations (coming soon until [PulseShareConfig]
/// lists some), and ways to spread the word. Everything shown here is driven
/// by [PulseShareConfig].
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  /// The store page to rate Pulse on this platform, if it has one yet.
  static String? get rateUrl {
    if (Platform.isAndroid) return PulseShareConfig.playStoreUrl;
    if (Platform.isIOS || Platform.isMacOS) return PulseShareConfig.appStoreUrl;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final wide = !context.isCompact;
    const hero = _Hero();
    const donate = _Donations();
    final spread = SettingsGroup(
      items: [
        (r) => SettingsValueItem(
          icon: PulseIcons.share,
          title: 'Share Pulse',
          subtitle: 'Send the app to a friend',
          chevron: true,
          onTap: () => shareApp(context),
        ),
        if (PulseShareConfig.showRateApp && rateUrl != null)
          (r) => SettingsValueItem(
            icon: PulseIcons.star,
            title: 'Rate Pulse',
            subtitle: 'A rating helps others find it',
            chevron: true,
            onTap: () => openExternalLink(context, rateUrl!),
          ),
        if (PulseShareConfig.showStarOnGitHub)
          (r) => SettingsValueItem(
            icon: PulseIcons.code,
            title: 'Star it on GitHub',
            subtitle: 'Pulse is open source',
            chevron: true,
            onTap: () => openExternalLink(context, PulseShareConfig.sourceUrl),
          ),
        if (PulseShareConfig.showFeedback)
          (r) => SettingsValueItem(
            icon: PulseIcons.help,
            title: 'Send feedback',
            subtitle: 'Ideas, bugs, anything',
            chevron: true,
            onTap: () => launchUrl(Uri(scheme: 'mailto', path: kDeveloper.email, query: 'subject=Pulse feedback')),
          ),
      ],
    );
    final results = SettingsGroup(
      items: [
        (r) => const SettingsValueItem(
          icon: PulseIcons.gauge,
          title: 'Share your results',
          subtitle:
              'Use the share button on Ping, Speed test, Traceroute, Packet loss or any run in History. '
              'IP addresses stay hidden unless you turn them on.',
        ),
      ],
    );

    final List<Widget> children;
    if (wide) {
      children = [
        hero,
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [PulseSectionLabel('Donate'), donate],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [const PulseSectionLabel('Spread the word'), spread, const SizedBox(height: 12), results],
              ),
            ),
          ],
        ),
      ];
    } else {
      children = [
        hero,
        const PulseSectionLabel('Donate'),
        donate,
        const PulseSectionLabel('Spread the word'),
        spread,
        const SizedBox(height: 12),
        results,
      ];
    }
    return PulsePage(title: 'Support us', backTo: Routes.settings, showBack: true, children: children);
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
      decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(32)),
      child: Column(
        children: [
          const PulsePop(
            child: PulseShapeBadge(shape: PulseShape.cookie9, tone: PulseTone.pink, icon: PulseIcons.heart, size: 96),
          ),
          const SizedBox(height: 18),
          Text('Keep Pulse free', textAlign: TextAlign.center, style: context.type.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Pulse has no ads, no accounts and no tracking, and it stays that way. '
            'If it helps you, here is how you can help it.',
            textAlign: TextAlign.center,
            style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// The donation options from [PulseShareConfig.donations], or a "coming soon"
/// card while there are none.
class _Donations extends StatelessWidget {
  const _Donations();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const options = PulseShareConfig.donations;
    if (options.isNotEmpty) {
      return SettingsGroup(
        items: [
          for (final o in options)
            (r) => SettingsValueItem(
              icon: PulseIcons.gift,
              title: o.label,
              subtitle: o.description,
              chevron: true,
              onTap: () => openExternalLink(context, o.url),
            ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(28)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PulseShapeBadge(shape: PulseShape.clover4, tone: PulseTone.lime, icon: PulseIcons.gift, size: 52),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text('Donations', style: context.type.titleMedium)),
                    const SizedBox(width: 8),
                    const PulsePill('Coming soon', tone: PulsePillTone.lime),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "We're setting up a simple way to chip in. Until then, sharing Pulse or rating it helps just as much.",
                  style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
