import 'package:flutter/material.dart';

import '../../../../core/domain/value_objects/repo_change.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
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
  late final Future<Result<List<RepoFileChange>>> _future = widget.loader();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return FutureBuilder<Result<List<RepoFileChange>>>(
      future: _future,
      builder: (context, snap) {
        final res = snap.data;
        final files = res is Ok<List<RepoFileChange>> ? res.value : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l.changedFiles,
                  style: context.typography.display.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                if (files != null && files.isNotEmpty) ...[
                  SizedBox(width: context.spacing.sm),
                  _CountBadge(files.length),
                ],
              ],
            ),
            SizedBox(height: context.spacing.lg),
            if (snap.connectionState != ConnectionState.done)
              const _Loading()
            else if (res is Err<List<RepoFileChange>>)
              _Muted(res.failure.message)
            else if (files == null || files.isEmpty)
              _Muted(l.noChangedFiles)
            else
              for (final file in files) _FileRow(file),
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
                      _open ? Icons.expand_less : Icons.expand_more,
                      size: context.spacing.xl3,
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

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.md),
      ),
      child: Text(
        '$count',
        style: context.typography.captionStrong.copyWith(
          color: c.textSecondary,
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.md),
      child: SizedBox(
        height: context.spacing.xl4,
        width: context.spacing.xl4,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.md),
      child: Text(
        text,
        style: context.typography.secondary.copyWith(
          color: context.colors.textTertiary,
        ),
      ),
    );
  }
}
