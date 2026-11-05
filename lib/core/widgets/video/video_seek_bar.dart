import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'video_time.dart';

/// A video's seek bar: track, what is loaded, what has played and a knob,
/// drawn from a smooth [position]. Hovering thickens it and shows the time
/// under the pointer; a click or drag moves the knob at once and seeks when
/// let go, so a streamed video isn't asked to seek on every pixel.
class VideoSeekBar extends StatefulWidget {
  const VideoSeekBar({super.key, required this.player, required this.position});

  final VideoPlayerController player;
  final Duration position;

  @override
  State<VideoSeekBar> createState() => _VideoSeekBarState();
}

class _VideoSeekBarState extends State<VideoSeekBar> {
  double? _hoverX;
  double? _dragFraction;

  double _fractionAt(double dx, double width) =>
      width <= 0 ? 0 : (dx / width).clamp(0.0, 1.0);

  void _drag(double dx, double width) =>
      setState(() => _dragFraction = _fractionAt(dx, width));

  Future<void> _commit() async {
    final fraction = _dragFraction;
    if (fraction == null) return;
    await widget.player.seekTo(widget.player.value.duration * fraction);
    if (mounted) setState(() => _dragFraction = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final v = widget.player.value;
    final total = v.duration.inMilliseconds;
    double frac(Duration d) =>
        total <= 0 ? 0 : (d.inMilliseconds / total).clamp(0.0, 1.0);
    final active = _hoverX != null || _dragFraction != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final pointerX = _dragFraction == null
            ? _hoverX
            : _dragFraction! * width;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onHover: (e) => setState(() => _hoverX = e.localPosition.dx),
          onExit: (_) => setState(() => _hoverX = null),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _drag(d.localPosition.dx, width),
            onTapUp: (_) => _commit(),
            onHorizontalDragStart: (d) => _drag(d.localPosition.dx, width),
            onHorizontalDragUpdate: (d) => _drag(d.localPosition.dx, width),
            onHorizontalDragEnd: (_) => _commit(),
            child: SizedBox(
              height: context.sizes.controlMd,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      duration: AppMotion.fast,
                      tween: Tween(end: active ? s.sm : s.xs),
                      builder: (context, thickness, _) => CustomPaint(
                        painter: _SeekBarPainter(
                          played: _dragFraction ?? frac(widget.position),
                          buffered: [
                            for (final r in v.buffered)
                              (frac(r.start), frac(r.end)),
                          ],
                          thickness: thickness,
                          knob: active ? s.md : s.sm,
                          track: c.mixT(c.textPrimary, 0.14),
                          loaded: c.mixT(c.textPrimary, 0.32),
                          accent: c.accent,
                        ),
                      ),
                    ),
                  ),
                  if (pointerX != null && total > 0)
                    _TimeBubble(
                      x: pointerX,
                      width: width,
                      label: formatVideoTime(
                        v.duration * _fractionAt(pointerX, width),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The time under the pointer, floating above the bar.
class _TimeBubble extends StatelessWidget {
  const _TimeBubble({
    required this.x,
    required this.width,
    required this.label,
  });

  final double x;
  final double width;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Positioned(
      bottom: context.sizes.controlMd,
      left: (x - s.xl3).clamp(0.0, (width - s.xl3 * 2).clamp(0.0, width)),
      child: IgnorePointer(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xxs),
          decoration: BoxDecoration(
            color: c.scrim.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(context.radii.sm),
          ),
          child: Text(
            label,
            style: context.typography.mono.copyWith(color: c.onScrim),
          ),
        ),
      ),
    );
  }
}

class _SeekBarPainter extends CustomPainter {
  _SeekBarPainter({
    required this.played,
    required this.buffered,
    required this.thickness,
    required this.knob,
    required this.track,
    required this.loaded,
    required this.accent,
  });

  final double played;
  final List<(double, double)> buffered;
  final double thickness;
  final double knob;
  final Color track;
  final Color loaded;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final radius = Radius.circular(thickness / 2);
    void bar(double from, double to, Color color) {
      if (to <= from) return;
      canvas.drawRRect(
        RRect.fromLTRBR(
          from * size.width,
          y - thickness / 2,
          to * size.width,
          y + thickness / 2,
          radius,
        ),
        Paint()..color = color,
      );
    }

    bar(0, 1, track);
    for (final (from, to) in buffered) {
      bar(from, to, loaded);
    }
    bar(0, played, accent);
    canvas.drawCircle(
      Offset(played * size.width, y),
      knob / 2,
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(_SeekBarPainter old) =>
      old.played != played ||
      old.thickness != thickness ||
      old.knob != knob ||
      old.buffered.length != buffered.length ||
      !_sameRanges(old.buffered, buffered) ||
      old.accent != accent;

  static bool _sameRanges(List<(double, double)> a, List<(double, double)> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
