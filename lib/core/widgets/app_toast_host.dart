import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import 'app_toast_card.dart';
import 'app_toast_controller.dart';

/// Owns the app's [AppToastController]. Sits above the `MaterialApp`, so
/// even a `ScaffoldMessenger`'s context (which is above the app's builder)
/// reaches it; [AppToastLayer], in the builder, draws the toasts.
class AppToasts extends StatefulWidget {
  const AppToasts({super.key, required this.child});

  final Widget child;

  /// The controller above [context], or null outside an [AppToasts].
  static AppToastController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_AppToastsScope>()?.notifier;

  @override
  State<AppToasts> createState() => _AppToastsState();
}

class _AppToastsState extends State<AppToasts> {
  final _controller = AppToastController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _AppToastsScope(notifier: _controller, child: widget.child);
}

class _AppToastsScope extends InheritedNotifier<AppToastController> {
  const _AppToastsScope({required super.notifier, required super.child});
}

/// Draws the toasts at the top centre, under the title bar, clear of the
/// inputs and actions along the bottom. Only the toasts take the pointer;
/// everything around them stays clickable.
class AppToastLayer extends StatelessWidget {
  const AppToastLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = context
        .dependOnInheritedWidgetOfExactType<_AppToastsScope>()
        ?.notifier;
    if (controller == null) return child;
    final s = context.spacing;
    return Stack(
      children: [
        child,
        Positioned(
          top: context.sizes.titleBarHeight + s.md,
          left: s.xl,
          right: s.xl,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.sizes.dialogSm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: s.sm,
                children: [
                  for (final t in controller.toasts)
                    AppToastCard(
                      key: ValueKey(t.id),
                      toast: t,
                      onDismiss: () => controller.dismiss(t.id),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
