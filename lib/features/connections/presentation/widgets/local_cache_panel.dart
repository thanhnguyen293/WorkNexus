import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/cache_section.dart';
import '../providers/local_cache_providers.dart';
import 'local_cache_section_row.dart';

/// The synced data kept in the local database, by section, every one picked
/// to start with; "Clear" drops the picked ones and hands them to
/// [onCleared] — the app resyncs them, which reaches into features this one
/// must not know. The local-data part of the app's storage dialog.
class LocalCachePanel extends ConsumerStatefulWidget {
  const LocalCachePanel({required this.onCleared, super.key});

  final void Function(Set<CacheSection> sections) onCleared;

  @override
  ConsumerState<LocalCachePanel> createState() => _LocalCachePanelState();
}

class _LocalCachePanelState extends ConsumerState<LocalCachePanel> {
  final _picked = {...CacheSection.values};
  var _clearing = false;

  void _toggle(CacheSection section) => setState(() {
    if (!_picked.remove(section)) _picked.add(section);
  });

  Future<void> _clear() async {
    final l = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final sections = {..._picked};
    setState(() => _clearing = true);
    final result = await ref.read(clearLocalCacheProvider)(sections);
    if (mounted) setState(() => _clearing = false);
    switch (result) {
      case Ok():
        widget.onCleared(sections);
        messenger.showSnackBar(SnackBar(content: Text(l.cacheCleared)));
      case Err(:final failure):
        messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    final radius = BorderRadius.circular(context.radii.lg);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.localCacheDbHint,
          style: context.typography.caption.copyWith(color: c.textSecondary),
        ),
        SizedBox(height: s.xl),
        // The same bordered, hairline-split card as the chat files above.
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: c.border),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Column(
              children: [
                for (final (i, section) in CacheSection.values.indexed) ...[
                  if (i > 0) Divider(height: 1, color: c.border),
                  LocalCacheSectionRow(
                    section: section,
                    picked: _picked.contains(section),
                    onToggle: () => _toggle(section),
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: s.lg),
        Text(
          l.clearCacheKept,
          style: context.typography.caption.copyWith(color: c.textTertiary),
        ),
        SizedBox(height: s.xl),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.error(
            isDisabled: _picked.isEmpty,
            isLoading: _clearing,
            onPressed: _clear,
            child: Text(l.clearCacheConfirm),
          ),
        ),
      ],
    );
  }
}
