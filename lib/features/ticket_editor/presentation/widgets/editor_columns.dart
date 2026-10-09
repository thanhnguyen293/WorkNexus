import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// The editor's layout: the text ([main]) beside the fields ([side]) when
/// there is room, as ZenTao's web form lays them out; one column below that.
class EditorColumns extends StatelessWidget {
  const EditorColumns({super.key, required this.main, required this.side});

  final Widget main;
  final Widget side;

  /// Below this width the fields go under the text.
  static const _twoColumns = 900.0;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= _twoColumns;
        return SingleChildScrollView(
          padding: EdgeInsets.all(s.xl5),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: main),
                    SizedBox(width: s.xl5),
                    SizedBox(
                      width: (box.maxWidth * 0.32).clamp(340.0, 440.0),
                      child: side,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    main,
                    SizedBox(height: s.xl5),
                    side,
                  ],
                ),
        );
      },
    );
  }
}
