import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Future<List<String>> getWifiDns() async {
  try {
    const channel = MethodChannel('network_info');
    final List<dynamic> dnsServers = await channel.invokeMethod('getWifiDns');
    return dnsServers.cast<String>();
  } on PlatformException catch (e) {
    if (kDebugMode) {
      print("Failed to get DNS: ${e.message}");
    }
    return [];
  }
}
