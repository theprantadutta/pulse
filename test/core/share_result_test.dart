import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/constants/share_config.dart';
import 'package:pulse/core/share/pulse_share.dart';
import 'package:pulse/core/widgets/pulse/pulse.dart';

void main() {
  const result = ShareableResult(
    tool: 'Traceroute',
    icon: PulseIcons.route,
    shape: PulseShape.arch,
    tone: PulseTone.lavender,
    headline: '33',
    unit: 'ms',
    caption: 'To reach the destination',
    target: 'dns.google · 8.8.8.8',
    stats: [ShareStat('Hops', '14'), ShareStat('First hop', '192.168.0.1'), ShareStat('Via', '2400:c600:55a4:5d67::1')],
  );

  test('IP addresses are hidden unless the user shows them', () {
    final hidden = result.text(hideAddresses: true);
    expect(hidden, isNot(contains('8.8.8.8')));
    expect(hidden, isNot(contains('192.168.0.1')));
    expect(hidden, isNot(contains('2400:c600')));
    expect(hidden, contains('dns.google · •••'));
    expect(hidden, contains('Hops: 14'));

    final shown = result.text(hideAddresses: false);
    expect(shown, contains('8.8.8.8'));
    expect(shown, contains('2400:c600:55a4:5d67::1'));
  });

  test('the card offers the address switch only when there are addresses', () {
    expect(result.hasAddresses, isTrue);
    const speed = ShareableResult(
      tool: 'Speed test',
      icon: PulseIcons.gauge,
      shape: PulseShape.sunny,
      tone: PulseTone.pink,
      headline: '245',
      caption: 'Download',
      target: 'Cloudflare · Dhaka',
      stats: [ShareStat('Upload', '48', unit: 'Mbps')],
    );
    expect(speed.hasAddresses, isFalse);
  });

  test('every shared result ends with the Pulse footer', () {
    expect(result.text(hideAddresses: true).trim().split('\n').last, PulseShareConfig.resultFooter);
  });

  test('no donation options means Support us shows "coming soon"', () {
    expect(PulseShareConfig.donations, isEmpty);
  });
}
