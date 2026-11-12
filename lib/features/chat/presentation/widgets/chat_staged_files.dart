import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/dropped_files.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_staged_files_provider.dart';
import 'chat_labels.dart';

/// Stands in for the composer's text input while files dropped on it wait:
/// their thumbnails, each removable, and the send button. Enter sends, Esc
/// removes them all; no text can be typed meanwhile.
class ChatStagedFiles extends ConsumerWidget {
  const ChatStagedFiles({
    super.key,
    required this.draftKey,
    required this.onSend,
    required this.onCleared,
  });

  final ChatComposerKey draftKey;

  /// Sends the files, which have already left the input.
  final ValueChanged<List<DroppedFile>> onSend;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final staged = chatStagedFilesProvider(draftKey);
    final files = ref.watch(staged);
    void send() {
      final out = ref.read(staged);
      ref.read(staged.notifier).state = const [];
      if (out.isNotEmpty) onSend(out);
    }

    void clear() {
      ref.read(staged.notifier).state = const [];
      onCleared();
    }

    void remove(int i) {
      final left = [...files]..removeAt(i);
      ref.read(staged.notifier).state = left;
      if (left.isEmpty) onCleared();
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): send,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): send,
        const SingleActivator(LogicalKeyboardKey.escape): clear,
      },
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: EdgeInsets.fromLTRB(s.xl3, s.md, s.lg, s.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: s.sm,
                  children: [
                    Wrap(
                      spacing: s.md,
                      runSpacing: s.md,
                      children: [
                        for (var i = 0; i < files.length; i++)
                          _StagedFile(
                            file: files[i],
                            onRemove: () => remove(i),
                          ),
                      ],
                    ),
                    Text(
                      l.chatStagedFilesHint,
                      style: context.typography.caption.copyWith(
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: s.md),
              IconButton(
                tooltip: '${l.chatSend} · ${l.chatSendHint}',
                onPressed: send,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: context.sizes.controlLg,
                  height: context.sizes.controlLg,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: c.onAccent,
                ),
                icon: Icon(LucideIcons.send500, size: context.sizes.iconLg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One waiting file: an image's thumbnail, else its type glyph and name,
/// with a remove button in the corner.
class _StagedFile extends StatelessWidget {
  const _StagedFile({required this.file, required this.onRemove});

  final DroppedFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final side = context.sizes.attachmentThumb;
    final decode = (side * MediaQuery.devicePixelRatioOf(context)).round();
    final image = isImageAttachment(file.name);
    return Tooltip(
      message: file.name,
      child: SizedBox.square(
        dimension: side,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(context.radii.md),
              child: ColoredBox(
                color: c.surfaceSubtle,
                child: image
                    ? Image.memory(
                        file.bytes,
                        fit: BoxFit.cover,
                        cacheWidth: decode,
                        errorBuilder: (_, _, _) =>
                            Icon(LucideIcons.image300, color: c.textSecondary),
                      )
                    : Padding(
                        padding: EdgeInsets.all(s.xs),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: s.xs,
                          children: [
                            Icon(
                              isVideoName(file.name)
                                  ? LucideIcons.film300
                                  : LucideIcons.file300,
                              color: c.textSecondary,
                              size: context.sizes.iconLg,
                            ),
                            Text(
                              file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.typography.caption.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            Positioned(
              top: s.xs,
              right: s.xs,
              // On a scrim chip so it reads over any thumbnail.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.scrim.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(context.radii.sm),
                ),
                child: AppIconButton(
                  icon: LucideIcons.x300,
                  tooltip: AppL10n.of(context).chatRemoveAttachment,
                  size: AppIconButtonSize.small,
                  color: c.onScrim,
                  onPressed: onRemove,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
