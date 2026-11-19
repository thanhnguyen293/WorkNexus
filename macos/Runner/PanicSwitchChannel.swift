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
    case "hide":
      guard let id = args?["id"] as? String else { return result(Self.badArgs) }
      for app in NSRunningApplication.runningApplications(withBundleIdentifier: id) {
        app.hide()
      }
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
      overlay?.show(image: image)
      result(nil)
    case "hideOverlay":
      overlay?.orderOut(nil)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
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
