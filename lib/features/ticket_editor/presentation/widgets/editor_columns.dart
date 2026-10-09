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
          padding: EdgeInsets.all(s.xl3),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: main),
                    SizedBox(width: s.xl3),
                    SizedBox(
                      width: (box.maxWidth * 0.3).clamp(300.0, 380.0),
                      child: side,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    main,
                    SizedBox(height: s.xl3),
                    side,
                  ],
                ),
        );
      },
    );
  }
}
