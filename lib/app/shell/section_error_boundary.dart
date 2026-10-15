import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_state_view.dart';

/// Wraps a viewport section or detail panel in an error boundary (specs F6).
/// If a crash occurs during build or layout of its subtree, it catches the error
/// and displays [AppStateView.error] with a Retry action, keeping the rail and
/// pane interactive.
class SectionErrorBoundary extends StatefulWidget {
  const SectionErrorBoundary({
    super.key,
    required this.child,
    this.onRetry,
    this.title,
    this.message,
  });

  final Widget child;
  final VoidCallback? onRetry;
  final String? title;
  final String? message;

  @override
  State<SectionErrorBoundary> createState() => SectionErrorBoundaryState();
}

class SectionErrorBoundaryState extends State<SectionErrorBoundary> {
  static ErrorWidgetBuilder? _prevErrorBuilder;
  static int _activeBoundaries = 0;

  Object? _caughtError;
  int _retryKey = 0;

  @override
  void initState() {
    super.initState();
    if (_activeBoundaries == 0) {
      _prevErrorBuilder = ErrorWidget.builder;
      ErrorWidget.builder = (details) =>
          _BoundaryErrorFallback(details: details);
    }
    _activeBoundaries++;
  }

  @override
  void dispose() {
    _activeBoundaries--;
    if (_activeBoundaries == 0 && _prevErrorBuilder != null) {
      ErrorWidget.builder = _prevErrorBuilder!;
      _prevErrorBuilder = null;
    }
    super.dispose();
  }

  /// Manually triggers an error state (e.g. from an async error).
  void captureError(Object error) {
    if (mounted) {
      setState(() => _caughtError = error);
    }
  }

  /// Retries building the child subtree by bumping the key and calling [onRetry].
  void retry() {
    setState(() {
      _caughtError = null;
      _retryKey++;
    });
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_caughtError != null) {
      return ColoredBox(
        color: context.colors.background,
        child: Center(
          child: AppStateView.error(
            title: widget.title,
            message: widget.message ?? _caughtError.toString(),
            onRetry: retry,
          ),
        ),
      );
    }

    return KeyedSubtree(key: ValueKey(_retryKey), child: widget.child);
  }
}

class _BoundaryErrorFallback extends StatelessWidget {
  const _BoundaryErrorFallback({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final boundary = context
        .findAncestorStateOfType<SectionErrorBoundaryState>();

    return ColoredBox(
      color: context.colors.background,
      child: Center(
        child: AppStateView.error(
          title: boundary?.widget.title,
          message: boundary?.widget.message,
          onRetry: boundary?.retry,
        ),
      ),
    );
  }
}
