import Cocoa
import FlutterMacOS
import ServiceManagement
import window_manager

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    LaunchAtLogin.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  // window_manager shows the window once Dart has sized it (launch window).
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}

/// `pulse/launch_at_login`: login item through SMAppService (macOS 13+).
enum LaunchAtLogin {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "pulse/launch_at_login", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard #available(macOS 13.0, *) else {
        result(FlutterError(code: "UNSUPPORTED", message: "Launch at login needs macOS 13 or later", details: nil))
        return
      }
      switch call.method {
      case "isEnabled":
        result(SMAppService.mainApp.status == .enabled)
      case "setEnabled":
        let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
        do {
          if enabled {
            try SMAppService.mainApp.register()
          } else {
            try SMAppService.mainApp.unregister()
          }
          result(nil)
        } catch {
          result(FlutterError(code: "LOGIN_ITEM", message: error.localizedDescription, details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
