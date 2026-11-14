import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/presentations/navigation/app_router.dart';
import 'package:pulse/presentations/navigation/destinations.dart';

void main() {
  test('a normal launch goes to Ping after the launch route', () {
    expect(launchDestination('/'), Routes.ping);
    expect(launchDestination(Routes.launch), Routes.ping);
  });

  test('the Monitor notification still lands on Monitor after boot', () {
    expect(launchDestination('/monitor'), Routes.monitor);
    expect(launchDestination('/traceroute?target=1.1.1.1'), '/traceroute?target=1.1.1.1');
  });
}
