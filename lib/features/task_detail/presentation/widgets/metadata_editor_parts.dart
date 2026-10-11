import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../l10n/app_localizations.dart';

/// The search box at the top of a metadata editor popover; it takes focus as
/// the popover opens so typing filters straight away.
class EditorSearchField extends StatelessWidget {
  const EditorSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.spacing.md),
      child: AppSearchField(
        controller: controller,
        hint: hint,
        autofocus: true,
        onChanged: onChanged,
      ),
    );
  }
}

class EditorOptionTile extends StatelessWidget {
  const EditorOptionTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.xl,
          vertical: context.spacing.md,
        ),
        child: Row(
          children: [
            SizedBox(
              width: context.spacing.xl5,
              child: selected
                  ? Icon(
                      LucideIcons.check300,
                      size: context.sizes.iconMd,
                      color: c.accent,
                    )
                  : null,
            ),
            if (leading != null) ...[
              leading!,
              SizedBox(width: context.spacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.body.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.bodySm.copyWith(
                        color: c.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditorFooter extends StatelessWidget {
  const EditorFooter({
    super.key,
    required this.busy,
    required this.onSave,
    this.error,
  });

  final bool busy;
  final VoidCallback? onSave;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return Container(
      padding: EdgeInsets.all(context.spacing.md),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          if (error != null)
            Expanded(
              child: Text(
                error!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.typography.bodySm.copyWith(color: c.error),
              ),
            )
          else
            const Spacer(),
          SizedBox(width: context.spacing.md),
          AppButton.filled(
            size: AppButtonSize.small,
            isLoading: busy,
            onPressed: onSave,
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}

class EditorMessage extends StatelessWidget {
  const EditorMessage({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.spacing.xl2),
      child: Text(
        message,
        style: context.typography.body.copyWith(
          color: context.colors.textTertiary,
        ),
      ),
    );
  }
}
