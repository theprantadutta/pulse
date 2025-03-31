import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Future<String> getWifiStrength() async {
  try {
    const channel = MethodChannel('network_info');
    final int strength = await channel.invokeMethod('getWifiSignalStrength');

    // Convert the 0-4 scale to percentage (0-100%)
    final percentage = (strength / 4 * 100).round();
    return '$percentage%';
  } on PlatformException catch (e) {
    if (kDebugMode) {
      print("Failed to get signal strength: ${e.message}");
    }
    return 'Unknown';
  }
}
