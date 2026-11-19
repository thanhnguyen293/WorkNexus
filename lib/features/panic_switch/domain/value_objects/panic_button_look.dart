/// How the floating button is set off: [wire] is the name the runner's native
/// code knows it by.
enum PanicGesture {
  doubleClick('double'),
  tripleClick('triple'),

  /// Pressed and held for a moment.
  hold('hold');

  const PanicGesture(this.wire);

  final String wire;

  static PanicGesture fromWire(String? wire) => values.firstWhere(
    (g) => g.wire == wire,
    orElse: () => PanicGesture.tripleClick,
  );
}

/// How the floating button looks and is set off, as the native window draws
/// it; [demo]: a right click offers the demo trigger. A record, so an
/// unchanged look compares equal and is not redrawn.
typedef PanicButtonLook = ({
  int size,
  double opacity,
  PanicGesture gesture,
  bool demo,
});

/// The choices offered for the floating button.
abstract final class PanicButtonChoices {
  /// Widths in logical pixels: small, medium, large.
  static const sizes = [80, 120, 160];

  /// From not faded at all to faded the most.
  static const opacities = [1.0, 0.8, 0.6, 0.4];
  static const defaultSize = 120;
  static const defaultOpacity = 1.0;
}
