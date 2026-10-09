import 'dart:math' as math;
import 'dart:ui';

/// One spark of a firework: where its burst is, which way and how fast it
/// flies, when its burst goes off (as a fraction of the show) and its colour
/// slot (an index into the caller's palette).
typedef Spark = ({
  Offset origin,
  double angle,
  double speed,
  double start,
  int colour,
});

/// How long one show runs, and how long each burst lives within it.
const fireworksDuration = Duration(milliseconds: 3200);
const _burstLife = 0.4;

/// Pulls sparks down, in logical pixels per second².
const _gravity = 260.0;

/// The sparks of a show over an area of [size]: [bursts] bursts across the
/// upper part of the area, going off in quick, overlapping succession. [seed] makes a show repeatable.
List<Spark> fireworkSparks(
  Size size, {
  required int seed,
  int bursts = 12,
  int sparksPerBurst = 48,
  int colours = 5,
}) {
  final random = math.Random(seed);
  return [
    for (var b = 0; b < bursts; b++)
      ...() {
        final origin = Offset(
          size.width * (0.08 + random.nextDouble() * 0.84),
          size.height * (0.1 + random.nextDouble() * 0.45),
        );
        // Spread over the show, a little irregular so bursts overlap.
        final start =
            (b + random.nextDouble() * 0.6) * (1 - _burstLife) / bursts;
        final colour = random.nextInt(colours);
        return [
          for (var i = 0; i < sparksPerBurst; i++)
            (
              origin: origin,
              angle:
                  i * 2 * math.pi / sparksPerBurst +
                  (random.nextDouble() - 0.5) * 0.2,
              speed: 160 + random.nextDouble() * 220,
              start: start,
              // Mostly the burst's colour, a few of the next for sparkle.
              colour: random.nextDouble() < 0.8
                  ? colour
                  : (colour + 1) % colours,
            ),
        ];
      }(),
  ];
}

/// Where [spark] is at [t] (0–1 through the show), how opaque, and how far
/// through its own life (0 at the burst, 1 burnt out); null before its burst
/// or after it has burnt out.
({Offset at, double opacity, double life})? sparkAt(Spark spark, double t) {
  final local = (t - spark.start) / _burstLife;
  if (local < 0 || local > 1) return null;
  final seconds = local * _burstLife * fireworksDuration.inMilliseconds / 1000;
  final at =
      spark.origin +
      Offset(
        math.cos(spark.angle) * spark.speed * seconds,
        math.sin(spark.angle) * spark.speed * seconds +
            0.5 * _gravity * seconds * seconds,
      );
  return (at: at, opacity: 1 - local * local, life: local);
}
