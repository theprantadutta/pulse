import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/presentations/navigation/destinations.dart';

void main() {
  test('system back walks up to the parent screen', () {
    expect(parentRoute('/alerts/rule'), Routes.alerts);
    expect(parentRoute(Routes.alerts), Routes.monitor);
    expect(parentRoute(Routes.monitor), Routes.tools);
    expect(parentRoute(Routes.traceroute), Routes.tools);
    expect(parentRoute(Routes.lan), Routes.tools);
    expect(parentRoute(Routes.settings), Routes.tools);
    expect(parentRoute(Routes.pingDetail), Routes.ping);
    expect(parentRoute(Routes.tools), Routes.ping);
    expect(parentRoute(Routes.network), Routes.ping);
    expect(parentRoute(Routes.history), Routes.ping);
    expect(parentRoute(Routes.ping), isNull);
  });

  test('tabs and rail selection', () {
    expect(tabFor('/ping/host'), MobileTab.ping);
    expect(tabFor(Routes.lan), MobileTab.tools);
    expect(tabFor(Routes.settings), MobileTab.tools);
    expect(railTabFor(Routes.settings), isNull);
    expect(isToolRoute('/alerts/rule'), isTrue);
    expect(isToolRoute(Routes.history), isFalse);
  });
}
