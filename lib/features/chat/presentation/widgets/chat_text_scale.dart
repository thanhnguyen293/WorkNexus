import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';

/// Scales the text of [child] by the chat text size from settings, on top of
/// the system's own scale: the conversation list, the messages, the composer
/// and the panels that show messages. Headers (search, tabs, titles) keep the
/// app's size so they stay aligned across panes.
class ChatTextScale extends ConsumerWidget {
  const ChatTextScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(appSettingsProvider.select((s) => s.chatTextScale));
    if (scale == 1) return child;
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: _Scaled(media.textScaler, scale)),
      child: child,
    );
  }
}

/// [base] (the system's scale) times [factor].
class _Scaled extends TextScaler {
  const _Scaled(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  double get textScaleFactor => base.scale(14) / 14 * factor;

  @override
  bool operator ==(Object other) =>
      other is _Scaled && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
