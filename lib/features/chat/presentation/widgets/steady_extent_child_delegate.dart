import 'package:flutter/widgets.dart';

import 'list_extent_estimate.dart';

/// A [SliverChildBuilderDelegate] whose length estimate comes from a
/// [ListExtentEstimate], so the scrollbar thumb stays steady over rows of
/// very different heights. Pass it to `ListView.custom`.
///
/// The [estimate] outlives the delegate (a new one is built with every
/// frame of the owning widget): keep it in that widget's state.
class SteadyExtentChildDelegate extends SliverChildBuilderDelegate {
  SteadyExtentChildDelegate(
    super.builder, {
    required this.estimate,
    required int super.childCount,
    super.findChildIndexCallback,
  });

  final ListExtentEstimate estimate;

  @override
  double? estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) => estimate.maxScrollOffset(
    lastIndex: lastIndex,
    trailingScrollOffset: trailingScrollOffset,
    // Required (non-null) by the constructor.
    childCount: childCount!,
  );
}
