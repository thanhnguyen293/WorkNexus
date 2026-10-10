import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../navigation/navigation_providers.dart';
import '../theme/app_borders.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'quick_settings_panel.dart';
import 'quick_settings_segmented.dart';

/// Quick Settings sliding over the window's right edge while
/// [quickSettingsOpenProvider] is set (over the current view, not beside
/// it). The app-wide controls (then [generalSections]) and the chat's
/// [chatSections] sit on separate tabs, each its own scroll. Escape, the
/// close button or a click outside closes it.
class QuickSettingsSidePanel extends ConsumerWidget {
  const QuickSettingsSidePanel({
    super.key,
    this.generalSections = const [],
    this.chatSections = const [],
  });

  /// Feature sections after the app-wide ones on the General tab.
  final List<Widget> generalSections;
  final List<Widget> chatSections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(quickSettingsOpenProvider)) return const SizedBox.shrink();
    final c = context.colors;
    void close() => ref.read(quickSettingsOpenProvider.notifier).state = false;
    return Stack(
      children: [
        Positioned.fill(
          child: ModalBarrier(
            color: c.scrim.withValues(alpha: _kScrimAlpha),
            onDismiss: close,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _Panel(
            onClose: close,
            generalSections: generalSections,
            chatSections: chatSections,
          ),
        ),
      ],
    );
  }
}

/// Dims what the panel covers; a tap on it closes the panel.
const double _kScrimAlpha = 0.18;

enum _Tab { general, chat }

class _Panel extends ConsumerStatefulWidget {
  const _Panel({
    required this.onClose,
    required this.generalSections,
    required this.chatSections,
  });

  final VoidCallback onClose;
  final List<Widget> generalSections;
  final List<Widget> chatSections;

  @override
  ConsumerState<_Panel> createState() => _PanelState();
}

class _PanelState extends ConsumerState<_Panel> {
  // Opened from the chat, the panel starts on the chat's own settings; read
  // once, so switching views underneath doesn't flip the tab.
  late var _tab = ref.read(chatOpenProvider) ? _Tab.chat : _Tab.general;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final close = widget.onClose;
    final hasChat = widget.chatSections.isNotEmpty;
    final tab = hasChat ? _tab : _Tab.general;
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent ||
            event.logicalKey != LogicalKeyboardKey.escape) {
          return KeyEventResult.ignored;
        }
        close();
        return KeyEventResult.handled;
      },
      child: Container(
        key: const ValueKey<String>('quick-settings-side-panel'),
        width: s.xl6 * 10,
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(left: context.hairlineSide),
          boxShadow: [
            BoxShadow(
              color: c.scrim.withValues(alpha: _kScrimAlpha),
              blurRadius: s.xl6,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(s.xl, s.md, s.md, s.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.quickSettings,
                      style: context.typography.title.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                    onPressed: close,
                    icon: Icon(LucideIcons.x300, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            if (hasChat)
              Padding(
                padding: EdgeInsets.fromLTRB(s.xl, s.none, s.xl, s.xl),
                child: QuickSettingsSegmented<_Tab>(
                  key: const ValueKey<String>('quick-settings-tabs'),
                  value: tab,
                  options: {
                    _Tab.general: l.quickSettingsGeneral,
                    _Tab.chat: l.chat,
                  },
                  onChanged: (t) => setState(() => _tab = t),
                ),
              ),
            Divider(height: 1, thickness: 1, color: c.border),
            Expanded(
              // A step darker than the cards, so each group stands apart.
              child: ColoredBox(
                color: c.background,
                child: SingleChildScrollView(
                  // A fresh scroll per tab, so switching starts at the top.
                  key: ValueKey<_Tab>(tab),
                  padding: EdgeInsets.all(s.xl),
                  child: switch (tab) {
                    _Tab.general => _SectionList(
                      sections: [
                        const QuickSettingsPanel(),
                        ...widget.generalSections,
                      ],
                    ),
                    _Tab.chat => _SectionList(sections: widget.chatSections),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tab's sections, one [QuickSettingsSection] per concern.
class _SectionList extends StatelessWidget {
  const _SectionList({required this.sections});

  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) SizedBox(height: context.spacing.xl5),
          sections[i],
        ],
      ],
    );
  }
}
