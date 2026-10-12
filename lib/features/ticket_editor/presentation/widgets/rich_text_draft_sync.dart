import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/html_editing_controller.dart';

/// Hands a rich-text field (a bug's steps, a task's description) to the
/// editor's draft once typing pauses. The field keeps its own text controller,
/// so without this the kept draft would only learn the text on Save.
mixin RichTextDraftSync<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  static const _pause = Duration(milliseconds: 400);

  Timer? _pending;
  HtmlEditingController? _text;
  void Function(String html)? _push;

  /// Hands [text] to [push] as it changes.
  void syncRichText(
    HtmlEditingController text,
    void Function(String html) push,
  ) {
    _text = text;
    _push = push;
    text.quill.addListener(_onChanged);
  }

  void _onChanged() {
    _pending?.cancel();
    _pending = Timer(_pause, pushRichText);
  }

  /// Hands the text on now (before saving or closing).
  void pushRichText() {
    _pending?.cancel();
    final text = _text;
    final push = _push;
    if (text != null && push != null && mounted) push(text.html);
  }

  /// Stops handing the text on; call before disposing the text controller.
  void stopRichTextSync() {
    _pending?.cancel();
    _text?.quill.removeListener(_onChanged);
    _text = null;
    _push = null;
  }
}
