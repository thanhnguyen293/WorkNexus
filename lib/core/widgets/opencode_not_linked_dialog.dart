import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../di/providers.dart';
import '../navigation/navigation_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/fonts.dart';
import 'app_button.dart';
import 'app_dialog_frame.dart';

/// True when a translation can run: through the user's API key, or through
/// an OpenCode CLI with an authenticated provider. Otherwise explains how to
/// link OpenCode (`opencode auth login`, or pick an API provider in Settings)
/// and returns false, rather than letting a translation fail with a raw CLI
/// error.
Future<bool> ensureOpenCodeLinked(BuildContext context, WidgetRef ref) async {
  if (await ref.read(translatesWithApiKeyProvider.future)) return true;
  if (await ref.read(openCodeAuthedProvider.future)) return true;
  if (!context.mounted) return false;
  await showDialog<void>(
    context: context,
    builder: (_) => const OpenCodeNotLinkedDialog(),
  );
  return false;
}

/// Explains how to link OpenCode when no provider is authenticated: run the CLI
/// login, or switch translation to an API-key provider in Settings.
class OpenCodeNotLinkedDialog extends ConsumerWidget {
  const OpenCodeNotLinkedDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final s = context.spacing;
    return AppDialogFrame(
      title: l.openCodeNotLinkedTitle,
      maxWidth: context.sizes.dialogSm,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.gotIt),
        ),
        AppButton.filled(
          size: AppButtonSize.small,
          icon: LucideIcons.settings300,
          onPressed: () {
            Navigator.of(context).pop();
            ref
                .read(appNavProvider.notifier)
                .selectWorkspaceSection(WorkspaceSection.settings);
          },
          child: Text(l.openCodeOpenSettings),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
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
            SizedBox(height: s.xl),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.lg),
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
    );
  }
}
