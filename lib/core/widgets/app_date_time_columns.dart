import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_time_input.dart';

/// Two scrollable columns for picking Hour (00–23) and Minute (00–55) side-by-side,
/// styled to match ZenTao web's datetime picker.
class AppDateTimeColumns extends StatefulWidget {
  const AppDateTimeColumns({
    super.key,
    required this.time,
    required this.onChanged,
  });

  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  State<AppDateTimeColumns> createState() => _AppDateTimeColumnsState();
}

class _AppDateTimeColumnsState extends State<AppDateTimeColumns> {
  static const double _itemHeight = 32.0;
  static const double _columnWidth = 44.0;

  late final ScrollController _hourScroll;
  late final ScrollController _minuteScroll;

  @override
  void initState() {
    super.initState();
    _hourScroll = ScrollController(
      initialScrollOffset: math.max(0, (widget.time.hour - 3) * _itemHeight),
    );
    final minIndex = _minuteOptions.indexOf(widget.time.minute);
    _minuteScroll = ScrollController(
      initialScrollOffset: math.max(
        0,
        ((minIndex >= 0 ? minIndex : widget.time.minute ~/ 5) - 3) *
            _itemHeight,
      ),
    );
  }

  @override
  void dispose() {
    _hourScroll.dispose();
    _minuteScroll.dispose();
    super.dispose();
  }

  List<int> get _minuteOptions {
    final list = <int>[for (var m = 0; m < 60; m += 5) m];
    final current = widget.time.minute;
    if (!list.contains(current)) {
      list.add(current);
      list.sort();
    }
    return list;
  }

  @override
  void didUpdateWidget(AppDateTimeColumns oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.time != widget.time) {
      if (_hourScroll.hasClients) {
        final target = math.max(0.0, (widget.time.hour - 3) * _itemHeight);
        _hourScroll.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
      if (_minuteScroll.hasClients) {
        final minIndex = _minuteOptions.indexOf(widget.time.minute);
        final target = math.max(
          0.0,
          ((minIndex >= 0 ? minIndex : widget.time.minute ~/ 5) - 3) *
              _itemHeight,
        );
        _minuteScroll.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final minutes = _minuteOptions;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        VerticalDivider(width: 1, thickness: 1, color: c.border),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: s.xs),
              child: AppTimeInput(
                value: widget.time,
                onChanged: widget.onChanged,
              ),
            ),
            Divider(height: 1, thickness: 1, color: c.border),
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: _columnWidth,
                    child: _ColumnList(
                      controller: _hourScroll,
                      itemCount: 24,
                      selectedPredicate: (i) => i == widget.time.hour,
                      labelBuilder: (i) => i.toString().padLeft(2, '0'),
                      onSelected: (h) => widget.onChanged(
                        TimeOfDay(hour: h, minute: widget.time.minute),
                      ),
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: c.border),
                  SizedBox(
                    width: _columnWidth,
                    child: _ColumnList(
                      controller: _minuteScroll,
                      itemCount: minutes.length,
                      selectedPredicate: (i) => minutes[i] == widget.time.minute,
                      labelBuilder: (i) => minutes[i].toString().padLeft(2, '0'),
                      onSelected: (i) => widget.onChanged(
                        TimeOfDay(hour: widget.time.hour, minute: minutes[i]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ColumnList extends StatelessWidget {
  const _ColumnList({
    required this.controller,
    required this.itemCount,
    required this.selectedPredicate,
    required this.labelBuilder,
    required this.onSelected,
  });

  final ScrollController controller;
  final int itemCount;
  final bool Function(int) selectedPredicate;
  final String Function(int) labelBuilder;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.symmetric(vertical: s.xs),
      itemCount: itemCount,
      itemExtent: 32.0,
      itemBuilder: (context, index) {
        final isSelected = selectedPredicate(index);
        final label = labelBuilder(index);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: s.xxs, vertical: 1),
          child: Material(
            color: isSelected ? c.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(context.radii.sm),
            child: InkWell(
              borderRadius: BorderRadius.circular(context.radii.sm),
              onTap: () => onSelected(index),
              child: Center(
                child: Text(
                  label,
                  style: isSelected
                      ? context.typography.bodySmStrong.copyWith(
                          color: c.onAccent,
                        )
                      : context.typography.bodySm.copyWith(
                          color: c.textSecondary,
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
