import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../navigation/navigation_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';

/// Title-bar trigger that docks or closes the Quick Settings side panel
/// (see [QuickSettingsSidePanel]); three quick taps open the debug log.
class QuickSettingsButton extends ConsumerStatefulWidget {
  const QuickSettingsButton({super.key});

  @override
  ConsumerState<QuickSettingsButton> createState() =>
      _QuickSettingsButtonState();
}

class _QuickSettingsButtonState extends ConsumerState<QuickSettingsButton> {
  DateTime? _firstTapAt;
  var _tapCount = 0;

  static const _debugTapWindow = Duration(milliseconds: 650);

  void _handleTriggerTap() {
    final now = DateTime.now();
    final firstTapAt = _firstTapAt;
    if (firstTapAt == null || now.difference(firstTapAt) > _debugTapWindow) {
      _firstTapAt = now;
      _tapCount = 0;
    }
    _tapCount++;
    final open = ref.read(quickSettingsOpenProvider.notifier);
    if (_tapCount >= 3) {
      _tapCount = 0;
      _firstTapAt = null;
      open.state = false;
      ref.read(talkerDebugOpenProvider.notifier).state = true;
      return;
    }
    open.state = !open.state;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isOpen = ref.watch(quickSettingsOpenProvider);
    final triggerSize = context.spacing.xl5 + context.spacing.xs;
    return SizedBox.square(
      key: const ValueKey<String>('quick-settings-trigger'),
      dimension: triggerSize,
      child: Tooltip(
        message: AppL10n.of(context).quickSettings,
        child: Semantics(
          button: true,
          label: AppL10n.of(context).quickSettings,
          child: Ink(
            decoration: BoxDecoration(
              color: isOpen ? c.selectionFill : null,
              borderRadius: BorderRadius.circular(context.radii.sm),
            ),
            child: InkWell(
              mouseCursor: WidgetStateMouseCursor.clickable,
              onTap: _handleTriggerTap,
              hoverColor: c.surfaceSubtle,
              borderRadius: BorderRadius.circular(context.radii.sm),
              child: Icon(
                LucideIcons.settings300,
                size: context.spacing.xl3,
                color: isOpen ? c.accent : c.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
