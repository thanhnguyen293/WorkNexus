import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/di/providers.dart';
import '../../core/domain/entities/workspace.dart';
import '../../core/navigation/navigation_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/tools/tool_registry_provider.dart';
import '../../core/widgets/app_popup_card.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/board/presentation/providers/board_providers.dart';
import 'workspace_switcher_footer.dart';
import 'workspace_switcher_row.dart';

/// Popover card to search, switch, or create workspaces (design §2, specs S2.2).
/// Features instant filter search, keyboard navigation (↑/↓/Enter/Esc),
/// connected tool indicators, and footer actions.
class WorkspaceSwitcherPopover extends ConsumerStatefulWidget {
  const WorkspaceSwitcherPopover({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  ConsumerState<WorkspaceSwitcherPopover> createState() =>
      _WorkspaceSwitcherPopoverState();
}

class _WorkspaceSwitcherPopoverState
    extends ConsumerState<WorkspaceSwitcherPopover> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  int _highlightIndex = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _selectWorkspace(Workspace ws) {
    ref.read(activeWorkspaceIdProvider.notifier).state = ws.id;
    ref.read(filterStateProvider.notifier).setWorkspace(ws.id);
    ref.read(appNavProvider.notifier).closeTicket();

    final allAccounts = ref.read(accountsProvider).asData?.value ?? const [];
    final newAccounts = allAccounts
        .where((a) => a.workspaceId == ws.id)
        .toList();
    final registry = ref.read(toolRegistryProvider);
    ref
        .read(appNavProvider.notifier)
        .onWorkspaceSwitched(newAccounts: newAccounts, registry: registry);

    _close();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final workspaces =
        ref.watch(workspacesProvider).asData?.value ?? const <Workspace>[];
    final activeId = ref.watch(activeWorkspaceIdProvider);
    final accounts = ref.watch(accountsProvider).asData?.value ?? const [];

    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? workspaces
        : workspaces
              .where((w) => w.name.toLowerCase().contains(query))
              .toList();

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _close();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          if (filtered.isNotEmpty) {
            setState(() {
              _highlightIndex = (_highlightIndex + 1) % filtered.length;
            });
          }
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          if (filtered.isNotEmpty) {
            setState(() {
              _highlightIndex =
                  (_highlightIndex - 1 + filtered.length) % filtered.length;
            });
          }
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter) {
          if (filtered.isNotEmpty &&
              _highlightIndex >= 0 &&
              _highlightIndex < filtered.length) {
            _selectWorkspace(filtered[_highlightIndex]);
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AppPopupCard(
        child: SizedBox(
          width: context.sizes.switcherPopoverWidth,
          height: context.sizes.switcherPopoverHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SearchHeader(
                controller: _searchCtrl,
                hintText: l.findWorkspace,
                onChanged: (_) {
                  setState(() => _highlightIndex = 0);
                },
              ),
              Divider(height: 1, color: c.border),
              Padding(
                padding: EdgeInsets.fromLTRB(s.lg, s.md, s.lg, s.xs),
                child: Text(
                  l.yourWorkspaces,
                  style: context.typography.labelWide.copyWith(
                    color: c.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: s.sm,
                    vertical: s.xs,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final ws = filtered[i];
                    final isSelected = activeId != null
                        ? ws.id == activeId
                        : (workspaces.isNotEmpty && i == 0);
                    final isHighlighted = i == _highlightIndex;
                    final subtitle = WorkspaceSwitcherRow.formatToolsSubtitle(
                      accounts,
                      ws.id,
                      l,
                    );

                    return WorkspaceSwitcherRow(
                      workspace: ws,
                      subtitle: subtitle,
                      isSelected: isSelected,
                      isHighlighted: isHighlighted,
                      onTap: () => _selectWorkspace(ws),
                    );
                  },
                ),
              ),
              Divider(height: 1, color: c.border),
              WorkspaceSwitcherFooter(onClose: _close),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xs),
      child: Row(
        children: [
          Icon(
            LucideIcons.search300,
            size: context.sizes.iconSm,
            color: c.textTertiary,
          ),
          SizedBox(width: s.sm),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              style: context.typography.bodySm,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: context.typography.bodySm.copyWith(
                  color: c.textTertiary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: s.sm),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
