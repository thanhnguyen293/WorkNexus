import 'package:flutter/painting.dart';

/// WCAG contrast ratio between two opaque colours (1–21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

/// [ink] made to read at [min]:1 on the opaque [background], keeping its
/// hue: only its lightness moves — lighter on dark fills, darker on light
/// ones — so a green stays green and a red stays red on any bubble. When no
/// lightness of that hue reads, it is mixed towards [towards] (the bubble's
/// text colour) instead.
Color readableOn(
  Color ink,
  Color background, {
  required Color towards,
  double min = 4.5,
}) {
  if (contrastRatio(ink, background) >= min) return ink;
  final hsl = HSLColor.fromColor(ink);
  final lighter = background.computeLuminance() < 0.5;
  for (var step = 1; step <= 20; step++) {
    final l = (hsl.lightness + (lighter ? step : -step) * 0.025).clamp(
      0.0,
      1.0,
    );
    final shifted = hsl.withLightness(l).toColor();
    if (contrastRatio(shifted, background) >= min) return shifted;
  }
  for (var t = 0.1; t < 1; t += 0.1) {
    final mixed = Color.lerp(ink, towards, t) ?? ink;
    if (contrastRatio(mixed, background) >= min) return mixed;
  }
  return towards;
}
