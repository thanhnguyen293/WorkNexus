import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../navigation/navigation_providers.dart';
import '../theme/app_borders.dart';
import '../theme/app_colors.dart';
import 'app_talker.dart';

class TalkerDebugOverlay extends ConsumerStatefulWidget {
  const TalkerDebugOverlay({super.key});

  @override
  ConsumerState<TalkerDebugOverlay> createState() => _TalkerDebugOverlayState();
}

class _TalkerDebugOverlayState extends ConsumerState<TalkerDebugOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  var _visible = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _close() => ref.read(talkerDebugOpenProvider.notifier).state = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(talkerDebugOpenProvider, (prev, next) {
      if (next) {
        setState(() => _visible = true);
        _c.forward();
      } else {
        _c.reverse().then((_) {
          if (mounted) setState(() => _visible = false);
        });
      }
    });

    if (!_visible && _c.isDismissed) return const SizedBox.shrink();

    final width = (MediaQuery.of(context).size.width * 0.52).clamp(
      460.0,
      760.0,
    );
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    final c = context.colors;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _c.value < 0.05,
                child: GestureDetector(
                  onTap: _close,
                  child: ColoredBox(
                    color: c.scrim.withValues(alpha: 0.5 * _c.value),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: width,
              child: FractionalTranslation(
                translation: Offset(1 - curve.value, 0),
                child: const _TalkerDebugPanel(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TalkerDebugPanel extends ConsumerWidget {
  const _TalkerDebugPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Material(
      key: const ValueKey<String>('talker-debug-panel'),
      color: c.card,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: c.border),
            top: BorderSide(color: c.accent, width: context.borders.accent),
          ),
        ),
        child: TalkerScreen(
          talker: appTalker,
          appBarTitle: 'WorkNexus Debug',
          appBarLeading: IconButton(
            tooltip: 'Close',
            onPressed: () =>
                ref.read(talkerDebugOpenProvider.notifier).state = false,
            icon: const Icon(Icons.close),
          ),
        ),
      ),
    );
  }
}
