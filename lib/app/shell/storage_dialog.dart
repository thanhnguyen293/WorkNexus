import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../features/chat/presentation/widgets/chat_storage_panel.dart';
import '../../features/connections/presentation/widgets/local_cache_panel.dart';
import '../../l10n/app_localizations.dart';
import 'reload_after_cache_clear.dart';

/// Widest / tallest the dialog grows, in logical pixels.
const _maxWidth = 640.0;
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
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _maxWidth,
          maxHeight: _maxHeight,
        ),
        child: Padding(
          padding: EdgeInsets.all(s.xl5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.storageTitle,
                style: context.typography.titleLg.copyWith(
                  color: c.textPrimary,
                ),
              ),
              SizedBox(height: s.xl3),
              // Title and Close stay put; both sections scroll between them
              // when the window is short.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionTitle(l.chatStorage),
                      const ChatStoragePanel(),
                      Divider(height: s.xl5 * 2, color: c.border),
                      _SectionTitle(l.localCacheTitle),
                      LocalCachePanel(
                        onCleared: (sections) =>
                            reloadAfterCacheClear(ref, sections),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: s.xl3),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton.textNeutral(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.close),
                ),
              ),
            ],
          ),
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
      style: context.typography.title.copyWith(
        color: context.colors.textPrimary,
      ),
    ),
  );
}
