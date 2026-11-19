import Cocoa
import FlutterMacOS

/// The native side of the panic switch ("Thầy vô",
/// lib/features/panic_switch/data/datasources/panic_switch_channel.dart):
/// lists apps, brings one forward, hides others, and owns the floating button.
final class PanicSwitchChannel {
  private let channel: FlutterMethodChannel
  private var overlay: PanicOverlayPanel?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "worknexus/panic_switch", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "listApps":
      result(Self.listApps())
    case "activate":
      guard let id = args?["id"] as? String else { return result(Self.badArgs) }
      Self.activate(bundleId: id, result: result)
    case "appIcon":
      guard let id = args?["id"] as? String else { return result(Self.badArgs) }
      result(Self.iconPng(bundleId: id).map { FlutterStandardTypedData(bytes: $0) })
    case "hideOthers":
      // Every app with a Dock icon but WorkNexus and the ones kept.
      let keep = Set((args?["keep"] as? [String]) ?? [])
      let me = NSRunningApplication.current.processIdentifier
      for app in NSWorkspace.shared.runningApplications
      where app.activationPolicy == .regular && app.processIdentifier != me {
        if let id = app.bundleIdentifier, keep.contains(id) { continue }
        app.hide()
      }
      result(nil)
      result(nil)
    case "hideSelf":
      NSApp.hide(nil)
      result(nil)
    case "showOverlay":
      guard let data = (args?["image"] as? FlutterStandardTypedData)?.data,
        let image = NSImage(data: data)
      else { return result(Self.badArgs) }
      if overlay == nil {
        overlay = PanicOverlayPanel { [weak self] demo in
          self?.channel.invokeMethod(
            "overlayTriggered", arguments: demo ? "demo" : "release")
        }
      }
      overlay?.show(
        image: image,
        width: CGFloat((args?["size"] as? NSNumber)?.doubleValue ?? 120),
        opacity: CGFloat((args?["opacity"] as? NSNumber)?.doubleValue ?? 1),
        gesture: args?["gesture"] as? String ?? "triple",
        demoLabel: args?["demoLabel"] as? String
      )
      result(nil)
    case "hideOverlay":
      overlay?.orderOut(nil)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// [bundleId]'s icon as a 64×64 PNG (32 points at 2×); nil when the app
  /// is not installed.
  private static func iconPng(bundleId: String) -> Data? {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
      return nil
    }
    let icon = NSWorkspace.shared.icon(forFile: url.path)
    let side = 64
    guard let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
      bytesPerRow: 0, bitsPerPixel: 0)
    else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    icon.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
  }

  private static let badArgs = FlutterError(code: "bad_args", message: "Missing argument", details: nil)

  /// Running apps with a Dock icon plus the apps in the usual folders, one
  /// entry per bundle id, by name.
  private static func listApps() -> [[String: String]] {
    var byId: [String: String] = [:]
    for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
      if let id = app.bundleIdentifier, let name = app.localizedName { byId[id] = name }
    }
    let fm = FileManager.default
    var folders = [
      URL(fileURLWithPath: "/Applications"),
      URL(fileURLWithPath: "/Applications/Utilities"),
      URL(fileURLWithPath: "/System/Applications"),
      URL(fileURLWithPath: "/System/Applications/Utilities"),
    ]
    folders.append(fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications"))
    for folder in folders {
      let items = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
      for url in items where url.pathExtension == "app" {
        guard let id = Bundle(url: url)?.bundleIdentifier, byId[id] == nil else { continue }
        byId[id] = fm.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
      }
    }
    return byId
      .map { ["id": $0.key, "name": $0.value] }
      .sorted { $0["name"]!.localizedCaseInsensitiveCompare($1["name"]!) == .orderedAscending }
  }

  /// Opening through LaunchServices brings a running app forward (with all
  /// its windows, unhidden) and starts one that is not running. Unlike
  /// NSRunningApplication.activate, macOS 14+ honours it while WorkNexus is
  /// itself in the background.
  private static func activate(bundleId: String, result: @escaping FlutterResult) {
    for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleId) {
      app.unhide()
    }
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
      return result(FlutterError(code: "not_found", message: "\(bundleId) is not installed", details: nil))
    }
    let config = NSWorkspace.OpenConfiguration()
    config.activates = true
    NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
      DispatchQueue.main.async {
        if let error {
          result(FlutterError(code: "open_failed", message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    }
  }
}
