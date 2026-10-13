import Cocoa
import FlutterMacOS
import window_manager

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

  // Keeps the window hidden until Dart has applied the window options (the
  // hidden title bar, the saved placement) and shows it. Without this macOS
  // puts the nib's titled window on screen at launch, and
  // DesktopWindowService.initialize() takes a visible window for a hot
  // restart and leaves the native title bar on.
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
