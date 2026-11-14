/// Everything about sharing and supporting Pulse lives here, so links, texts and
/// donation options change in one place without touching any screen.
library;

/// A way to support Pulse with money (shown on Settings › Support us).
class DonationOption {
  const DonationOption({required this.label, required this.description, required this.url});

  final String label;
  final String description;

  /// Opened in the browser after the usual confirmation.
  final String url;
}

abstract final class PulseShareConfig {
  static const appName = 'Pulse: Ping & Network Tools';
  static const tagline = 'Ping, traceroute, speed test, LAN scan and live monitoring in one app.';

  /// The link every share points to: the site sends people to the right store.
  static const websiteUrl = 'https://pulse.pranta.dev';
  static const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.pranta.pulse';

  /// Set once the iOS app is live; the rating row stays hidden on iOS until then.
  static const String? appStoreUrl = null;
  static const sourceUrl = 'https://github.com/theprantadutta/pulse_flutter_app';

  /// Donations aren't set up yet: an empty list shows "coming soon". Add
  /// options here (Ko-fi, Buy Me a Coffee, GitHub Sponsors…) and they appear as
  /// buttons on Support us.
  static const donations = <DonationOption>[];

  /// Rows under "Spread the word" on Support us.
  static const showRateApp = true;
  static const showStarOnGitHub = true;
  static const showFeedback = true;

  /// Result cards and texts leave IP addresses out unless the user turns them
  /// on in the share preview.
  static const hideAddressesByDefault = true;

  /// Text for "Share Pulse".
  static String get shareAppText => 'I use $appName to check my connection. $tagline\n$websiteUrl';

  /// Last line of every shared result.
  static const resultFooter = 'Measured with Pulse · pulse.pranta.dev';
}
