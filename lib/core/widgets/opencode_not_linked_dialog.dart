import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../di/providers.dart';
import '../navigation/navigation_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/fonts.dart';
import 'app_button.dart';

/// True when OpenCode has an authenticated provider. Otherwise explains how to
/// link one (Settings → OpenCode, or `opencode auth login`) and returns false,
/// rather than letting a translation fail with a raw CLI error.
Future<bool> ensureOpenCodeLinked(BuildContext context, WidgetRef ref) async {
  if (await ref.read(openCodeAuthedProvider.future)) return true;
  if (!context.mounted) return false;
  await showDialog<void>(
    context: context,
    builder: (_) => const OpenCodeNotLinkedDialog(),
  );
  return false;
}

/// Explains how to link OpenCode when no provider is authenticated: paste a key
/// in Settings, or run the CLI login for an OAuth provider.
class OpenCodeNotLinkedDialog extends ConsumerWidget {
  const OpenCodeNotLinkedDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      title: Row(
        children: [
          Text('🔗', style: context.typography.title),
          SizedBox(width: context.spacing.md),
          Text(
            l.openCodeNotLinkedTitle,
            style: context.typography.title.copyWith(color: c.textPrimary),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.openCodeNotLinkedBody,
              style: context.typography.paragraph.copyWith(
                color: c.textSecondary,
              ),
            ),
            SizedBox(height: context.spacing.xl),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: context.spacing.xl,
                vertical: context.spacing.lg,
              ),
              decoration: BoxDecoration(
                color: c.surfaceSubtle,
                borderRadius: BorderRadius.circular(context.radii.md),
                border: Border.all(color: c.border),
              ),
              child: SelectableText(
                'opencode auth login',
                style: context.typography.body.copyWith(
                  fontFamily: kMonoFont,
                  color: c.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        AppButton.textNeutral(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.gotIt),
        ),
        SizedBox(width: context.spacing.md),
        AppButton.filled(
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(openTicketIdProvider.notifier).close();
            ref.read(settingsOpenProvider.notifier).state = true;
          },
          child: Text(l.openCodeOpenSettings),
        ),
      ],
    );
  }
}
