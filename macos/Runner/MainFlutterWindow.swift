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

  // The Flutter title bar (TitleBar, AppSizes.macTitleBarHeight) is 52pt
  // tall; the traffic lights are centred in it, 19pt in from the left and
  // top — where a unified toolbar puts them. An empty toolbar did that, but
  // since macOS 26 it also rounds the window's corners to 26pt instead of
  // the 16pt of a window without one, so the lights are placed by hand.
  private static let titleBarHeight: CGFloat = 52
  private static let trafficLightInset: CGFloat = 19
  private static let trafficLightSpacing: CGFloat = 23
  private static let trafficLights: [NSWindow.ButtonType] = [
    .closeButton, .miniaturizeButton, .zoomButton,
  ]

  // AppKit puts the traffic lights back in its own title bar whenever it lays
  // the window out (resizing, style changes); they are moved after each
  // pass, before it is drawn.
  override func layoutIfNeeded() {
    super.layoutIfNeeded()
    placeTrafficLights()
  }

  private func placeTrafficLights() {
    // Full screen shows the system's own title bar on hover.
    guard !styleMask.contains(.fullScreen),
      let titleBar = standardWindowButton(.closeButton)?.superview,
      let container = titleBar.superview
    else { return }
    let height = Self.titleBarHeight
    var bar = container.frame
    if bar.height != height || bar.minY != frame.height - height {
      bar.size.height = height
      bar.origin.y = frame.height - height
      container.frame = bar
    }
    for (i, type) in Self.trafficLights.enumerated() {
      guard let button = standardWindowButton(type) else { continue }
      let origin = NSPoint(
        x: Self.trafficLightInset + CGFloat(i) * Self.trafficLightSpacing,
        y: ((titleBar.frame.height - button.frame.height) / 2).rounded()
      )
      if button.frame.origin != origin { button.setFrameOrigin(origin) }
    }
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
