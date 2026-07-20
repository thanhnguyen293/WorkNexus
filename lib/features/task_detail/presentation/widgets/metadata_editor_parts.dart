import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';

InputDecoration editorInputDecoration(
  BuildContext context, {
  required String hintText,
}) {
  final c = context.colors;
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: c.surfaceSubtle,
    hintText: hintText,
    hintStyle: context.typography.body.copyWith(color: c.textTertiary),
    contentPadding: EdgeInsets.symmetric(
      horizontal: context.spacing.lg,
      vertical: context.spacing.lg,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.radii.md),
      borderSide: BorderSide(color: c.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.radii.md),
      borderSide: BorderSide(color: c.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.radii.md),
      borderSide: BorderSide(color: c.accent),
    ),
  );
}

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
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.all(context.spacing.md),
      child: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        style: context.typography.body.copyWith(color: c.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: c.surfaceSubtle,
          hintText: hint,
          hintStyle: context.typography.body.copyWith(color: c.textTertiary),
          prefixIcon: Icon(
            Icons.search,
            size: context.spacing.xl4,
            color: c.textTertiary,
          ),
          prefixIconConstraints: BoxConstraints(minWidth: context.spacing.xl6),
          contentPadding: EdgeInsets.symmetric(vertical: context.spacing.lg),
          border: _border(context, c.border),
          enabledBorder: _border(context, c.border),
          focusedBorder: _border(context, c.accent),
        ),
      ),
    );
  }

  OutlineInputBorder _border(BuildContext context, Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.radii.md),
      borderSide: BorderSide(color: color),
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
                      Icons.check,
                      size: context.spacing.xl4,
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
  const EditorMessage({
    super.key,
    required this.message,
    this.isError = false,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.spacing.xl2),
      child: Text(
        message,
        style: context.typography.body.copyWith(
          color: isError ? context.colors.error : context.colors.textTertiary,
        ),
      ),
    );
  }
}
