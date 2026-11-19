import 'package:flutter/material.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/find_whats_new.dart';
import 'update_release_notes.dart';
import 'update_version_change.dart';

/// Shown once after an update: the versions jumped and what every release
/// in between brought.
class WhatsNewDialog extends StatelessWidget {
  const WhatsNewDialog({required this.news, super.key});

  final WhatsNew news;

  static Future<void> show(BuildContext context, WhatsNew news) => showDialog(
    context: context,
    builder: (_) => WhatsNewDialog(news: news),
  );

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    return AppDialogFrame(
      title: l.whatsNewTitle(news.to.startsWith('v') ? news.to : 'v${news.to}'),
      maxWidth: context.sizes.dialogLg,
      actions: [
        const Spacer(),
        AppButton.filled(
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.gotIt),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: UpdateVersionChange(from: news.from, to: news.to),
            ),
            SizedBox(height: s.xl2),
            UpdateReleaseNotes(notes: news.notes),
          ],
        ),
      ),
    );
  }
}
