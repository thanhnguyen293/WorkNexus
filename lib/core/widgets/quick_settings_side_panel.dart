import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../navigation/navigation_providers.dart';
import '../theme/app_borders.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'quick_settings_panel.dart';

/// Quick Settings sliding over the window's right edge while
/// [quickSettingsOpenProvider] is set (over the current view, not beside
/// it): the app-wide controls, then any feature [sections] (the app shell
/// passes the chat's look), one scroll. Escape, the close button or a click
/// outside closes it.
class QuickSettingsSidePanel extends ConsumerWidget {
  const QuickSettingsSidePanel({super.key, this.sections = const []});

  final List<Widget> sections;

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
          child: _Panel(onClose: close, sections: sections),
        ),
      ],
    );
  }
}

/// Dims what the panel covers; a tap on it closes the panel.
const double _kScrimAlpha = 0.18;

class _Panel extends StatelessWidget {
  const _Panel({required this.onClose, required this.sections});

  final VoidCallback onClose;
  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final close = onClose;
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
        width: s.xl6 * 9.5,
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
                      AppL10n.of(context).quickSettings,
                      style: context.typography.title.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                    onPressed: close,
                    icon: Icon(PhosphorIconsLight.x, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: c.border),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(s.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const QuickSettingsPanel(),
                    for (final section in sections) ...[
                      Divider(
                        height: s.xl4 * 1.5,
                        thickness: 1,
                        color: c.border,
                      ),
                      section,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
