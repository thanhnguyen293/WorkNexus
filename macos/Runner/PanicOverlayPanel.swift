import Cocoa

/// The panic switch's floating button: a borderless panel above every app and
/// Space (full-screen ones too) that never takes focus. Drag to move; three
/// clicks in a row call `onTrigger`. Where it was left is remembered.
final class PanicOverlayPanel: NSPanel {
  private static let width: CGFloat = 120

  init(onTrigger: @escaping () -> Void) {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.width),
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

  func show(image: NSImage) {
    let size = image.size.width > 0
      ? NSSize(width: Self.width, height: Self.width * image.size.height / image.size.width)
      : NSSize(width: Self.width, height: Self.width)
    (contentView as? OverlayView)?.image = image
    setContentSize(size)
    if !setFrameUsingName("WorkNexusPanicOverlay") {
      center()
    }
    setFrameAutosaveName("WorkNexusPanicOverlay")
    orderFrontRegardless()
  }
}

private final class OverlayView: NSImageView {
  private let onTrigger: () -> Void
  private var dragStart: NSPoint?
  private var dragged = false

  init(onTrigger: @escaping () -> Void) {
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
    if !dragged && event.clickCount == 3 { onTrigger() }
    dragStart = nil
  }
}
