import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// Rebuilds [builder] with [player]'s position every frame while it plays.
///
/// The platform reports the position only a few times a second, so a bar
/// drawn from it steps. Between reports this advances the last one by the
/// time elapsed (at the playback speed), and only snaps to a report when it
/// is clearly off (a seek, a stall) — never backwards for a late report.
class SmoothVideoPosition extends StatefulWidget {
  const SmoothVideoPosition({
    super.key,
    required this.player,
    required this.builder,
  });

  final VideoPlayerController player;
  final Widget Function(BuildContext context, Duration position) builder;

  @override
  State<SmoothVideoPosition> createState() => _SmoothVideoPositionState();
}

class _SmoothVideoPositionState extends State<SmoothVideoPosition>
    with SingleTickerProviderStateMixin {
  /// A report this far from the shown position is a jump, not drift.
  static const _snap = Duration(milliseconds: 300);

  late final Ticker _ticker = createTicker(_tick);
  final _sinceBase = Stopwatch();
  Duration _base = Duration.zero;
  Duration _reported = Duration.zero;
  Duration _shown = Duration.zero;

  @override
  void initState() {
    super.initState();
    _base = _shown = _reported = widget.player.value.position;
    widget.player.addListener(_sync);
    _sync();
  }

  void _sync() {
    final v = widget.player.value;
    final moving = v.isPlaying && !v.isBuffering;
    if (v.position != _reported) {
      _reported = v.position;
      final off = (v.position - _shown).abs();
      _base = !moving || off > _snap ? v.position : _shown;
      _sinceBase
        ..reset()
        ..start();
    }
    if (moving && !_ticker.isActive) {
      _sinceBase
        ..reset()
        ..start();
      _base = _shown;
      _ticker.start();
    } else if (!moving && _ticker.isActive) {
      _ticker.stop();
      _base = v.position;
    }
    if (!moving) setState(() => _shown = v.position);
  }

  void _tick(Duration _) {
    final v = widget.player.value;
    final next = _base + _sinceBase.elapsed * v.playbackSpeed;
    setState(() => _shown = next > v.duration ? v.duration : next);
  }

  @override
  void dispose() {
    widget.player.removeListener(_sync);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _shown);
}
