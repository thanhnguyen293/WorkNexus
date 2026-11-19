import Cocoa

/// The panic switch's floating button: a borderless panel above every app and
/// Space (full-screen ones too) that never takes focus. Drag to move; the
/// chosen gesture (two or three clicks in a row, or a long press) with the
/// left button calls `onTrigger(false)`, with the right one `onTrigger(true)`
/// (the demo trigger). Where it was left is remembered.
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
  func show(image: NSImage, width: CGFloat, opacity: CGFloat, gesture: String) {
    let size = image.size.width > 0
      ? NSSize(width: width, height: width * image.size.height / image.size.width)
      : NSSize(width: width, height: width)
    if let view = contentView as? OverlayView {
      view.image = image
      view.gesture = gesture
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
  /// When each button (left, right) went down, for the long press.
  private var pressedAt: [Bool: Date] = [:]
  /// "double", "triple" or "hold".
  var gesture = "triple"

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
    pressedAt[false] = Date()
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
    if !dragged { released(event, demo: false) }
    dragStart = nil
  }

  // Not passed on, so no context menu opens; the up event carries the count.
  override func rightMouseDown(with event: NSEvent) {
    pressedAt[true] = Date()
  }

  override func rightMouseUp(with event: NSEvent) {
    released(event, demo: true)
  }

  private func released(_ event: NSEvent, demo: Bool) {
    let fires: Bool
    switch gesture {
    case "hold":
      let since = pressedAt[demo].map { Date().timeIntervalSince($0) } ?? 0
      fires = since >= Self.holdTime
    case "double":
      fires = event.clickCount == 2
    default:
      fires = event.clickCount == 3
    }
    pressedAt[demo] = nil
    if fires { onTrigger(demo) }
  }
}
