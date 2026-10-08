import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// Scrolls a board's columns sideways, with an always-visible scrollbar
/// along the bottom. The columns' own (vertical) scrollbars stay hidden.
class BoardHorizontalScroll extends StatefulWidget {
  const BoardHorizontalScroll({super.key, required this.child});

  /// The row of columns.
  final Widget child;

  @override
  State<BoardHorizontalScroll> createState() => _BoardHorizontalScrollState();
}

class _BoardHorizontalScrollState extends State<BoardHorizontalScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _controller,
    thumbVisibility: true,
    child: ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.all(context.spacing.xl2),
        child: widget.child,
      ),
    ),
  );
}
