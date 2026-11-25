import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Makes message text — and only message text — selectable through the one
/// `SelectionArea` around a list of messages.
///
/// Wraps the list's slivers (below its `Scrollable`, so a drag past the edge
/// still scrolls the list): everything under it is left out of the selection
/// (sender names, times, reactions, quotes), except what a
/// [MessageTextSelection] puts back. A `SelectableText` per message did the
/// same, but built a text field (focus, scrollable, editable) for every row.
class MessageSelectionScope extends StatelessWidget {
  const MessageSelectionScope({super.key, required this.child});

  /// A sliver or a box: this adds no render object.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final registrar = SelectionContainer.maybeOf(context);
    if (registrar == null) return child;
    return _ListRegistrar(
      registrar: registrar,
      child: SelectionContainer.disabled(child: child),
    );
  }
}

/// The text of one message, selectable in the list's selection (see
/// [MessageSelectionScope]); under any other selection area as usual.
class MessageTextSelection extends StatefulWidget {
  const MessageTextSelection({super.key, required this.child});

  final Widget child;

  @override
  State<MessageTextSelection> createState() => _MessageTextSelectionState();
}

class _MessageTextSelectionState extends State<MessageTextSelection> {
  final _delegate = _MessageSelectionDelegate();

  @override
  void dispose() {
    _delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registrar =
        _ListRegistrar.maybeOf(context) ?? SelectionContainer.maybeOf(context);
    if (registrar == null) return widget.child;
    return SelectionContainer(
      registrar: registrar,
      delegate: _delegate,
      child: widget.child,
    );
  }
}

/// The selection of the list a [MessageSelectionScope] closed off.
class _ListRegistrar extends InheritedWidget {
  const _ListRegistrar({required this.registrar, required super.child});

  final SelectionRegistrar registrar;

  static SelectionRegistrar? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ListRegistrar>()?.registrar;

  @override
  bool updateShouldNotify(_ListRegistrar oldWidget) =>
      registrar != oldWidget.registrar;
}

/// Ends a message's selected text with a line break when the selection goes
/// on below the message: the list's selection joins the texts of its
/// messages with nothing between them, so copied messages ran together.
///
/// Every message is told where both ends of a drag are, so a selection
/// reaching past this message's bottom — dragged down or up — gets the
/// break; one stopped beside its last line (to take its last words) does not.
class _MessageSelectionDelegate extends StaticSelectionContainerDelegate {
  Offset? _start;
  Offset? _end;
  bool _all = false;

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    switch (event) {
      case SelectionEdgeUpdateEvent(:final type, :final globalPosition):
        if (type == SelectionEventType.startEdgeUpdate) {
          _start = globalPosition;
        } else {
          _end = globalPosition;
        }
      case SelectAllSelectionEvent():
        _all = true;
      case ClearSelectionEvent() ||
          SelectWordSelectionEvent() ||
          SelectParagraphSelectionEvent():
        _start = _end = null;
        _all = false;
      default:
    }
    return super.dispatchSelectionEvent(event);
  }

  @override
  SelectedContent? getSelectedContent() {
    final content = super.getSelectedContent();
    if (content == null || !(_all || _goesOnBelow())) return content;
    return SelectedContent(plainText: '${content.plainText}\n');
  }

  bool _goesOnBelow() {
    double? bottom;
    for (final selectable in selectables) {
      final rect = MatrixUtils.transformRect(
        selectable.getTransformTo(null),
        Offset.zero & selectable.size,
      );
      if (bottom == null || rect.bottom > bottom) bottom = rect.bottom;
    }
    if (bottom == null) return false;
    return (_start?.dy ?? double.negativeInfinity) > bottom ||
        (_end?.dy ?? double.negativeInfinity) > bottom;
  }
}
