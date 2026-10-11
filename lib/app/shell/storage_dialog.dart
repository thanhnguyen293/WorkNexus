import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_dialog_frame.dart';
import '../../features/chat/presentation/widgets/chat_storage_panel.dart';
import '../../features/connections/presentation/widgets/local_cache_panel.dart';
import '../../l10n/app_localizations.dart';
import 'reload_after_cache_clear.dart';

/// Tallest the dialog grows, in logical pixels.
const _maxHeight = 900.0;

/// The one place to free space: downloaded chat files on top, the synced
/// local data below. Lives in the app because it joins two features.
class StorageDialog extends ConsumerWidget {
  const StorageDialog({super.key});

  static Future<void> show(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const StorageDialog());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    return AppDialogFrame(
      title: l.storageTitle,
      maxWidth: context.sizes.dialogLg,
      maxHeight: _maxHeight,
      // Close sits in the header; both sections scroll under it when the
      // window is short.
      actions: const [],
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionTitle(l.chatStorage),
            const ChatStoragePanel(),
            Divider(height: s.xl5 * 2, color: c.border),
            _SectionTitle(l.localCacheTitle),
            LocalCachePanel(
              onCleared: (sections) => reloadAfterCacheClear(ref, sections),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: context.spacing.lg),
    child: Text(
      text,
      style: context.typography.titleSm.copyWith(
        color: context.colors.textPrimary,
      ),
    ),
  );
}
