import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/locator.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/adapters/ticket_detail_service.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import 'action_dialog_scaffold.dart';
import 'metadata_editor_parts.dart';

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
  final _search = TextEditingController();
  String _query = '';
  bool _initialized = false;
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The candidates matching the current search query (by display name or
  /// account handle). An empty query keeps the full list.
  List<ProviderUser> _visible(List<ProviderUser> users) {
    if (_query.isEmpty) return users;
    final q = _query.toLowerCase();
    return users
        .where(
          (u) =>
              u.displayName.toLowerCase().contains(q) ||
              u.account.toLowerCase().contains(q),
        )
        .toList();
  }

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
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final res = await getIt<TicketDetailService>().setReviewers(
      widget.ticket,
      _selected.toList(),
    );
    if (!mounted) return;
    showAppSnack(
      context,
      res.isOk
          ? l.reviewersUpdated
          : l.actionFailed(
              res.failureOrNull?.message ?? l.providerActionFailed,
            ),
      isError: !res.isOk,
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final users = ref.watch(providerUsersProvider(widget.ticket.id));
    return ActionScaffold(
      title: l.zentaoActionTitle(l.reviewers, widget.ticket.externalKey),
      submitLabel: l.save,
      icon: LucideIcons.users300,
      busy: _busy,
      onSubmit: _submit,
      child: users.when(
        loading: () => const AppStateView.loading(compact: true),
        error: (_, _) => AppStateView.error(
          compact: true,
          title: l.taskDetailUsersLoadFailed,
          onRetry: () =>
              ref.invalidate(providerUsersProvider(widget.ticket.id)),
        ),
        data: (list) {
          _initSelection(list);
          if (list.isEmpty) {
            return AppStateView.empty(
              compact: true,
              icon: LucideIcons.users300,
              title: l.taskDetailNoAssignableUsers,
            );
          }
          final visible = _visible(list);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel(l.reviewers),
              AppSearchField(
                controller: _search,
                hint: l.searchUsers,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
              ),
              SizedBox(height: context.spacing.sm),
              ConstrainedBox(
                // Room for about seven rows before the list scrolls.
                constraints: BoxConstraints(
                  maxHeight: context.sizes.controlLg * 7,
                ),
                child: visible.isEmpty
                    ? EditorMessage(message: l.noMatchingUsers)
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final u in visible)
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
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(context.radii.sm),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
        child: Row(
          children: [
            Icon(
              selected ? LucideIcons.squareCheck500 : LucideIcons.square300,
              size: context.sizes.iconMd,
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
