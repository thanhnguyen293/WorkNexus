import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/value_objects/repo_change.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import 'detail_section_title.dart';
import 'unified_diff_view.dart';

typedef ChangedFilesLoader = Future<Result<List<RepoFileChange>>> Function();

/// Lists the changed files on a merge request / pull request (loaded on demand);
/// each file expands to its unified diff. Shared by the GitLab MR and GitHub PR
/// two-pane details.
class ChangedFilesSection extends StatefulWidget {
  const ChangedFilesSection({super.key, required this.loader});

  final ChangedFilesLoader loader;

  @override
  State<ChangedFilesSection> createState() => _ChangedFilesSectionState();
}

class _ChangedFilesSectionState extends State<ChangedFilesSection> {
  late Future<Result<List<RepoFileChange>>> _future = widget.loader();

  void _retry() => setState(() => _future = widget.loader());

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return FutureBuilder<Result<List<RepoFileChange>>>(
      future: _future,
      builder: (context, snap) {
        final res = snap.data;
        final files = res is Ok<List<RepoFileChange>> ? res.value : null;
        final Widget body;
        if (snap.hasError) {
          body = AppStateView.error(compact: true, onRetry: _retry);
        } else if (snap.connectionState != ConnectionState.done) {
          body = const AppStateView.loading(compact: true);
        } else if (res case Err<List<RepoFileChange>>(:final failure)) {
          body = AppStateView.error(
            compact: true,
            message: failure.message,
            onRetry: _retry,
          );
        } else if (files == null || files.isEmpty) {
          body = AppStateView.empty(
            compact: true,
            icon: LucideIcons.fileDiff300,
            title: l.noChangedFiles,
          );
        } else {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final file in files) _FileRow(file)],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailSectionTitle(l.changedFiles, count: files?.length),
            body,
          ],
        );
      },
    );
  }
}

class _FileRow extends StatefulWidget {
  const _FileRow(this.file);

  final RepoFileChange file;

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final file = widget.file;
    final hasDiff = (file.diff ?? '').isNotEmpty;
    final (glyph, glyphColor) = switch ((file.status ?? '').toLowerCase()) {
      'added' => ('A', c.success),
      'deleted' || 'removed' => ('D', c.error),
      'renamed' => ('R', c.info),
      _ => ('M', c.warning),
    };
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: hasDiff ? () => setState(() => _open = !_open) : null,
            borderRadius: BorderRadius.circular(context.radii.sm),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
              child: Row(
                children: [
                  Text(
                    glyph,
                    style: context.typography.captionStrong.copyWith(
                      color: glyphColor,
                    ),
                  ),
                  SizedBox(width: context.spacing.md),
                  Expanded(
                    child: Text(
                      file.path,
                      style: context.typography.mono.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  if (file.additions > 0) ...[
                    SizedBox(width: context.spacing.sm),
                    Text(
                      '+${file.additions}',
                      style: context.typography.captionStrong.copyWith(
                        color: c.success,
                      ),
                    ),
                  ],
                  if (file.deletions > 0) ...[
                    SizedBox(width: context.spacing.sm),
                    Text(
                      '−${file.deletions}',
                      style: context.typography.captionStrong.copyWith(
                        color: c.error,
                      ),
                    ),
                  ],
                  if (hasDiff)
                    Icon(
                      _open
                          ? LucideIcons.chevronUp300
                          : LucideIcons.chevronDown300,
                      size: context.sizes.iconMd,
                      color: c.textTertiary,
                    ),
                ],
              ),
            ),
          ),
          if (_open && hasDiff) UnifiedDiffView(file.diff!),
        ],
      ),
    );
  }
}
