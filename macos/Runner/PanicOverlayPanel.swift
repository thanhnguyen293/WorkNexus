import Cocoa

/// The panic switch's floating button: a borderless panel above every app and
/// Space (full-screen ones too) that never takes focus. Drag to move; the
/// chosen gesture (two or three clicks in a row, or a long press) calls
/// `onTrigger(false)`. In demo mode a right click opens a menu whose one item
/// calls `onTrigger(true)` (the demo trigger). Where it was left is
/// remembered.
final class PanicOverlayPanel: NSPanel {
  init(onTrigger: @escaping (Bool) -> Void) {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 120, height: 120),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: true
    )
    level = .statusBar
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    hidesOnDeactivate = false
    isReleasedWhenClosed = false
    contentView = OverlayView(onTrigger: onTrigger)
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  /// Shows [image] [width] points wide at [opacity] (0…1), set off by
  /// [gesture]: "double", "triple" or "hold".
  /// [demoLabel] titles the right-click menu's demo item; nil: no menu.
  func show(
    image: NSImage, width: CGFloat, opacity: CGFloat, gesture: String, demoLabel: String?
  ) {
    let size = image.size.width > 0
      ? NSSize(width: width, height: width * image.size.height / image.size.width)
      : NSSize(width: width, height: width)
    if let view = contentView as? OverlayView {
      view.image = image
      view.gesture = gesture
      view.demoLabel = demoLabel
    }
    alphaValue = opacity
    setContentSize(size)
    if !setFrameUsingName("WorkNexusPanicOverlay") {
      center()
    }
    setFrameAutosaveName("WorkNexusPanicOverlay")
    orderFrontRegardless()
  }
}

private final class OverlayView: NSImageView {
  private let onTrigger: (Bool) -> Void
  private var dragStart: NSPoint?
  private var dragged = false
  /// When the button went down, for the long press.
  private var pressedAt: Date?
  /// "double", "triple" or "hold".
  var gesture = "triple"
  /// The right-click menu's demo item; nil when demo mode is off.
  var demoLabel: String?

  /// A press at least this long is a long press.
  private static let holdTime: TimeInterval = 0.8

  init(onTrigger: @escaping (Bool) -> Void) {
    self.onTrigger = onTrigger
    super.init(frame: .zero)
    imageScaling = .scaleProportionallyUpOrDown
  }

  required init?(coder: NSCoder) { fatalError("not used") }

  // A click on an inactive app's panel still counts as a click.
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func mouseDown(with event: NSEvent) {
    dragStart = NSEvent.mouseLocation
    dragged = false
    pressedAt = Date()
  }

  override func mouseDragged(with event: NSEvent) {
    guard let start = dragStart, let window else { return }
    let now = NSEvent.mouseLocation
    let dx = now.x - start.x
    let dy = now.y - start.y
    if !dragged && abs(dx) < 3 && abs(dy) < 3 { return }
    dragged = true
    window.setFrameOrigin(NSPoint(x: window.frame.origin.x + dx, y: window.frame.origin.y + dy))
    dragStart = now
  }

  override func mouseUp(with event: NSEvent) {
    if !dragged { released(event) }
    dragStart = nil
  }

  override func rightMouseDown(with event: NSEvent) {
    guard let demoLabel else { return }
    let menu = NSMenu()
    let item = NSMenuItem(title: demoLabel, action: #selector(demoChosen), keyEquivalent: "")
    item.target = self
    menu.addItem(item)
    NSMenu.popUpContextMenu(menu, with: event, for: self)
  }

  @objc private func demoChosen() { onTrigger(true) }

  private func released(_ event: NSEvent) {
    let fires: Bool
    switch gesture {
    case "hold":
      fires = pressedAt.map { Date().timeIntervalSince($0) >= Self.holdTime } ?? false
    case "double":
      fires = event.clickCount == 2
    default:
      fires = event.clickCount == 3
    }
    pressedAt = nil
    if fires { onTrigger(false) }
  }
}
