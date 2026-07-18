import 'package:flutter/material.dart';

import '../theme/app_button_theme.dart';
import '../theme/app_radii.dart';

export '../theme/app_button_theme.dart' show AppButtonSize, AppButtonVariant;

/// The app's themed button. Use a variant factory (`AppButton.filled(...)`) for
/// the design-system look, or the default constructor with an explicit [style]
/// to fully override. Geometry (size + component radius) is layered on top of
/// the variant style, so a single variant style serves every size and reacts to
/// the user's radius setting.
class AppButton extends StatelessWidget {
  /// Escape hatch: a fully custom [style]. Size + component radius are still
  /// applied on top unless the caller baked a `shape` into [style].
  const AppButton({
    required this.child,
    required this.style,
    this.size = AppButtonSize.medium,
    this.isDisabled = false,
    this.isLoading = false,
    this.onPressed,
    super.key,
  }) : _variant = null;

  const AppButton._({
    required AppButtonVariant variant,
    required this.child,
    this.size = AppButtonSize.medium,
    this.isDisabled = false,
    this.isLoading = false,
    this.onPressed,
    super.key,
  }) : _variant = variant,
       style = null;

  final Widget child;
  final AppButtonSize size;
  final bool isDisabled;
  final bool isLoading;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final AppButtonVariant? _variant;

  factory AppButton.filled({
    required Widget child,
    AppButtonSize size = AppButtonSize.medium,
    bool isDisabled = false,
    bool isLoading = false,
    VoidCallback? onPressed,
    Key? key,
  }) => AppButton._(
    variant: AppButtonVariant.filled,
    size: size,
    isDisabled: isDisabled,
    isLoading: isLoading,
    onPressed: onPressed,
    key: key,
    child: child,
  );

  factory AppButton.filledNeutral({
    required Widget child,
    AppButtonSize size = AppButtonSize.medium,
    bool isDisabled = false,
    bool isLoading = false,
    VoidCallback? onPressed,
    Key? key,
  }) => AppButton._(
    variant: AppButtonVariant.filledNeutral,
    size: size,
    isDisabled: isDisabled,
    isLoading: isLoading,
    onPressed: onPressed,
    key: key,
    child: child,
  );

  factory AppButton.outlined({
    required Widget child,
    AppButtonSize size = AppButtonSize.medium,
    bool isDisabled = false,
    bool isLoading = false,
    VoidCallback? onPressed,
    Key? key,
  }) => AppButton._(
    variant: AppButtonVariant.outlined,
    size: size,
    isDisabled: isDisabled,
    isLoading: isLoading,
    onPressed: onPressed,
    key: key,
    child: child,
  );

  factory AppButton.outlinedNeutral({
    required Widget child,
    AppButtonSize size = AppButtonSize.medium,
    bool isDisabled = false,
    bool isLoading = false,
    VoidCallback? onPressed,
    Key? key,
  }) => AppButton._(
    variant: AppButtonVariant.outlinedNeutral,
    size: size,
    isDisabled: isDisabled,
    isLoading: isLoading,
    onPressed: onPressed,
    key: key,
    child: child,
  );

  factory AppButton.text({
    required Widget child,
    AppButtonSize size = AppButtonSize.medium,
    bool isDisabled = false,
    bool isLoading = false,
    VoidCallback? onPressed,
    Key? key,
  }) => AppButton._(
    variant: AppButtonVariant.text,
    size: size,
    isDisabled: isDisabled,
    isLoading: isLoading,
    onPressed: onPressed,
    key: key,
    child: child,
  );

  factory AppButton.textNeutral({
    required Widget child,
    AppButtonSize size = AppButtonSize.medium,
    bool isDisabled = false,
    bool isLoading = false,
    VoidCallback? onPressed,
    Key? key,
  }) => AppButton._(
    variant: AppButtonVariant.textNeutral,
    size: size,
    isDisabled: isDisabled,
    isLoading: isLoading,
    onPressed: onPressed,
    key: key,
    child: child,
  );

  factory AppButton.error({
    required Widget child,
    AppButtonSize size = AppButtonSize.medium,
    bool isDisabled = false,
    bool isLoading = false,
    VoidCallback? onPressed,
    Key? key,
  }) => AppButton._(
    variant: AppButtonVariant.error,
    size: size,
    isDisabled: isDisabled,
    isLoading: isLoading,
    onPressed: onPressed,
    key: key,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveStyle(context);
    final enabled = !isDisabled && !isLoading && onPressed != null;
    return ElevatedButton(
      style: resolved,
      onPressed: enabled ? onPressed : null,
      child: _Content(isLoading: isLoading, style: resolved, child: child),
    );
  }

  ButtonStyle _resolveStyle(BuildContext context) {
    final shape = WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.component),
      ),
    );
    // Size + component radius are layered on top of the base (variant or custom)
    // style, but only where the caller hasn't already specified them.
    final base = style ?? (_variant ?? AppButtonVariant.filled).style(context);
    return base.copyWith(
      minimumSize: base.minimumSize ?? WidgetStatePropertyAll(size.minimumSize),
      padding: base.padding ?? WidgetStatePropertyAll(size.padding),
      textStyle:
          base.textStyle ?? WidgetStatePropertyAll(size.textStyle(context)),
      shape: base.shape ?? shape,
    );
  }
}

/// Swaps the label for a size-matched spinner while [isLoading], keeping the
/// button width stable and tinted to the resolved foreground color.
class _Content extends StatelessWidget {
  const _Content({
    required this.isLoading,
    required this.style,
    required this.child,
  });

  final bool isLoading;
  final ButtonStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;
    final fg = style.foregroundColor?.resolve(<WidgetState>{});
    final dim = (style.textStyle?.resolve(<WidgetState>{})?.fontSize ?? 14) + 2;
    return SizedBox(
      width: dim,
      height: dim,
      child: CircularProgressIndicator(strokeWidth: 2, color: fg),
    );
  }
}
