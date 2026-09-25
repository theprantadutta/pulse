import Flutter
import Foundation
import NetworkExtension
import SystemConfiguration
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "PulseNetworkInfo") {
      PulseNetworkInfo.register(with: registrar)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// iOS side of the `network_info` channel: DNS servers (libresolv), Wi-Fi
/// security (NEHotspotNetwork) and VPN detection (scoped proxy interfaces).
final class PulseNetworkInfo: NSObject {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "network_info", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getNetworkDetails":
        details { result($0) }
      case "getWifiDns":
        result(dnsServers())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func details(_ done: @escaping ([String: Any]) -> Void) {
    var out: [String: Any] = [
      "dns": dnsServers(),
      "vpn": vpnActive(),
    ]
    NEHotspotNetwork.fetchCurrent { network in
      if let network = network {
        out["ssid"] = network.ssid
        out["bssid"] = network.bssid
        out["security"] = securityName(network.securityType)
      }
      DispatchQueue.main.async { done(out) }
    }
  }

  private static func securityName(_ type: NEHotspotNetworkSecurityType) -> String? {
    switch type {
    case .open: return "OPEN"
    case .WEP: return "WEP"
    case .personal: return "WPA2"
    case .enterprise: return "WPA2-EAP"
    case .unknown: return nil
    @unknown default: return nil
    }
  }

  static func dnsServers() -> [String] {
    var state = __res_9_state()
    guard res_9_ninit(&state) == 0 else { return [] }
    defer { res_9_ndestroy(&state) }
    var servers = [res_9_sockaddr_union](repeating: res_9_sockaddr_union(), count: 8)
    let count = Int(res_9_getservers(&state, &servers, Int32(servers.count)))
    var out: [String] = []
    for i in 0..<max(0, count) {
      let server = servers[i]
      if server.sin.sin_family == sa_family_t(AF_INET) {
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        var addr = server.sin.sin_addr
        if inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil {
          out.append(String(cString: buffer))
        }
      } else if server.sin6.sin6_family == sa_family_t(AF_INET6) {
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        var addr = server.sin6.sin6_addr
        if inet_ntop(AF_INET6, &addr, &buffer, socklen_t(INET6_ADDRSTRLEN)) != nil {
          out.append(String(cString: buffer))
        }
      }
    }
    return out
  }

  static func vpnActive() -> Bool {
    guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
          let scoped = settings["__SCOPED__"] as? [String: Any] else { return false }
    return scoped.keys.contains { key in
      ["tap", "tun", "ppp", "ipsec", "utun"].contains { key.hasPrefix($0) }
    }
  }
}
