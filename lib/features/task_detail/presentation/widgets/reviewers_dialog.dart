import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../sync/data/sync_service.dart';
import 'action_dialog_scaffold.dart';

/// Multi-select reviewer picker for a GitLab MR / GitHub PR. Candidates are the
/// ticket's provider members; the current reviewers are pre-checked. Submitting
/// sets (GitLab) or requests (GitHub) the checked logins.
class ReviewersDialog extends ConsumerStatefulWidget {
  const ReviewersDialog({super.key, required this.ticket});
  final Ticket ticket;

  @override
  ConsumerState<ReviewersDialog> createState() => _ReviewersDialogState();
}

class _ReviewersDialogState extends ConsumerState<ReviewersDialog> {
  final Set<String> _selected = {};
  bool _initialized = false;
  bool _busy = false;

  List<String> _currentReviewers() => switch (widget.ticket.providerEntity) {
    GitLabItemEntity(:final reviewers) => reviewers,
    GitHubItemEntity(:final reviewers) => reviewers,
    _ => const <String>[],
  };

  /// Pre-check the users already reviewing (matched by login or display name).
  /// Runs once, when the candidate list first resolves.
  void _initSelection(List<ProviderUser> users) {
    if (_initialized) return;
    _initialized = true;
    final current = _currentReviewers().toSet();
    for (final u in users) {
      if (current.contains(u.account) || current.contains(u.displayName)) {
        _selected.add(u.account);
      }
    }
  }

  Future<void> _submit() async {
    final l = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final res = await getIt<SyncService>().setReviewers(
      widget.ticket,
      _selected.toList(),
    );
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          res.isOk
              ? l.reviewersUpdated
              : 'Failed: ${res.failureOrNull?.message ?? 'error'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final users = ref.watch(providerUsersProvider(widget.ticket.id));
    return ActionScaffold(
      emoji: '👀',
      title: '${l.reviewers} #${widget.ticket.externalKey}',
      submitLabel: l.save,
      busy: _busy,
      onSubmit: _submit,
      child: users.when(
        loading: () => Padding(
          padding: EdgeInsets.all(context.spacing.xl2),
          child: const Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Text(
          'Could not load users',
          style: context.typography.bodySm.copyWith(color: c.error),
        ),
        data: (list) {
          _initSelection(list);
          if (list.isEmpty) {
            return Text(
              'No assignable users',
              style: context.typography.bodySm.copyWith(color: c.textTertiary),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel(l.reviewers),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final u in list)
                      _ReviewerTile(
                        user: u,
                        selected: _selected.contains(u.account),
                        onChanged: (v) => setState(() {
                          if (v) {
                            _selected.add(u.account);
                          } else {
                            _selected.remove(u.account);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A single tappable reviewer row with a checkbox.
class _ReviewerTile extends StatelessWidget {
  const _ReviewerTile({
    required this.user,
    required this.selected,
    required this.onChanged,
  });

  final ProviderUser user;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(context.radii.sm),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: selected ? c.accent : c.textTertiary,
            ),
            SizedBox(width: context.spacing.md),
            Expanded(
              child: Text(
                user.displayName,
                overflow: TextOverflow.ellipsis,
                style: context.typography.body.copyWith(color: c.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
