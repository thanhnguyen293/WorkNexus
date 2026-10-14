import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_count_badge.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/paged_view_state.dart';
import '../../domain/usecases/should_auto_load.dart';
import '../../domain/value_objects/paging_policy.dart';

/// The end of a paged board column whose view has more pages. The list only
/// builds it once it scrolls into reach, so building it is what loads the next
/// pages — again and again while the column stays short — showing card
/// skeletons meanwhile. Under a filter that has stopped turning up cards it
/// asks first ("Load more"), and a failed page offers a retry.
class PagedColumnFooter extends StatelessWidget {
  const PagedColumnFooter({
    super.key,
    required this.stream,
    required this.visible,
    required this.filtered,
    required this.errorText,
    required this.onLoadMore,
    required this.onRetry,
  });

  /// What the column's view has loaded so far.
  final PagedViewState stream;

  /// How many of the view's cards the board shows; none gets more skeletons,
  /// as the board's own loading skeleton does.
  final int visible;

  /// Whether the board's filter can hide loaded cards.
  final bool filtered;

  /// What a failed page says above its retry.
  final String errorText;

  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    if (stream.failure != null) {
      return _FooterAction(
        note: AppInlineNote(text: errorText, isError: true),
        label: l.retry,
        icon: LucideIcons.rotateCw300,
        onPressed: onRetry,
      );
    }
    final auto = const ShouldAutoLoad()(
      AutoLoadQuery(state: stream, filtered: filtered, visible: visible),
    );
    if (!auto && !stream.loading) {
      final scanned = math.min(stream.page * kPagedViewPageSize, stream.total);
      return _FooterAction(
        note: AppInlineNote(text: l.pagedScanned(scanned, stream.total)),
        label: l.pagedLoadMore,
        icon: LucideIcons.chevronsDown300,
        onPressed: onLoadMore,
      );
    }
    if (auto) WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
    return Column(
      children: [
        for (var i = 0; i < (visible == 0 ? 3 : 2); i++) ...[
          if (i > 0) SizedBox(height: context.spacing.md),
          SkeletonBox(
            width: double.infinity,
            height: 78,
            radius: context.radii.sm,
          ),
        ],
      ],
    );
  }
}

/// A note over a small button at a column's end.
class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.note,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final Widget note;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
      child: Column(
        children: [
          note,
          SizedBox(height: context.spacing.xs),
          AppButton.textNeutral(
            size: AppButtonSize.small,
            icon: icon,
            onPressed: onPressed,
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

/// A paged column's ticket count; a trailing "+" while it can load more.
class PagedColumnCount extends StatelessWidget {
  const PagedColumnCount(this.count, {super.key, this.more = false});

  final int count;
  final bool more;

  @override
  Widget build(BuildContext context) {
    if (!more) return AppCountBadge(count);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: context.spacing.xxs,
      children: [
        AppCountBadge(count),
        Text(
          '+',
          style: context.typography.monoXs.copyWith(
            color: context.colors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
