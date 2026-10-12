import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // The unread count on the Dock icon (lib/core/platform/app_icon_badge.dart).
    FlutterMethodChannel(
      name: "worknexus/app_icon_badge",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { call, result in
      guard call.method == "set" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let label = (call.arguments as? [String: Any])?["label"] as? String ?? ""
      NSApp.dockTile.badgeLabel = label.isEmpty ? nil : label
      result(nil)
    }

    super.awakeFromNib()
  }
}
