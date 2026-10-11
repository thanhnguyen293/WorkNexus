import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

enum _StateKind { empty, error, loading }

/// The app's one treatment for a view with nothing to show yet: **empty**
/// (nothing matched / nothing exists), **error** (the load failed, with a
/// Retry) and **loading**.
///
/// Centred in whatever space it is given: an icon tile, a title, an optional
/// message and an optional action. [compact] drops the tile to a bare icon and
/// tightens the spacing for side panels, popovers and list sections.
class AppStateView extends StatelessWidget {
  const AppStateView.empty({
    super.key,
    required this.title,
    this.icon = LucideIcons.inbox300,
    this.message,
    this.action,
    this.compact = false,
  }) : onRetry = null,
       _kind = _StateKind.empty;

  /// A failed load. [title] defaults to a generic "Couldn't load this" and
  /// [message] to a connection hint; [onRetry] adds the Retry button.
  const AppStateView.error({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.icon = LucideIcons.cloudOff300,
    this.compact = false,
  }) : action = null,
       _kind = _StateKind.error;

  /// A centred spinner with an optional [title] underneath.
  const AppStateView.loading({super.key, this.title, this.compact = false})
    : icon = null,
      message = null,
      action = null,
      onRetry = null,
      _kind = _StateKind.loading;

  final String? title;
  final IconData? icon;
  final String? message;

  /// A button under the message (e.g. "Clear all filters").
  final Widget? action;
  final VoidCallback? onRetry;
  final bool compact;
  final _StateKind _kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    final l = AppL10n.of(context);
    final isError = _kind == _StateKind.error;
    final title = this.title ?? (isError ? l.stateLoadFailedTitle : null);
    final message = this.message ?? (isError ? l.stateLoadFailedHint : null);
    final retry = onRetry;
    final action =
        this.action ??
        (retry == null
            ? null
            : AppButton.outlinedNeutral(
                size: AppButtonSize.small,
                onPressed: retry,
                child: Text(l.retry),
              ));

    final Widget leading = switch (_kind) {
      _StateKind.loading => SizedBox.square(
        dimension: compact ? context.sizes.iconMd : context.sizes.iconXl,
        child: const CircularProgressIndicator(),
      ),
      _ => _StateIcon(icon: icon!, isError: isError, compact: compact),
    };

    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: context.sizes.stateMessage),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          if (title != null) ...[
            SizedBox(height: compact ? s.md : s.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: (compact ? t.bodyStrong : t.titleSm).copyWith(
                color: _kind == _StateKind.loading
                    ? c.textSecondary
                    : c.textPrimary,
              ),
            ),
          ],
          if (message != null) ...[
            SizedBox(height: s.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: (compact ? t.bodySm : t.secondary).copyWith(
                color: c.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          if (action != null) ...[
            SizedBox(height: compact ? s.lg : s.xl3),
            action,
          ],
        ],
      ),
    );

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? s.xl : s.xl5),
        // Errors are announced as they appear; an empty view is not news.
        child: Semantics(liveRegion: isError, child: content),
      ),
    );
  }
}

/// The glyph above the title: a soft rounded tile in the full layout, the
/// bare icon in the compact one. Errors take the error hue.
class _StateIcon extends StatelessWidget {
  const _StateIcon({
    required this.icon,
    required this.isError,
    required this.compact,
  });

  final IconData icon;
  final bool isError;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = isError ? c.error : c.textTertiary;
    if (compact) {
      return Icon(icon, size: context.sizes.iconLg, color: ink);
    }
    return Container(
      width: context.sizes.stateTile,
      height: context.sizes.stateTile,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isError ? c.mixT(c.error, 0.10) : c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      child: Icon(icon, size: context.sizes.iconXl, color: ink),
    );
  }
}
