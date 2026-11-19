import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/editor_chip.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/app_ref.dart';
import '../../domain/entities/panic_switch_config.dart';
import '../providers/panic_switch_providers.dart';
import 'panic_switch_save.dart';

/// The apps opened when the switch goes off, first in front: any number,
/// each removable. Every other app is hidden.
class PanicOpenAppsPicker extends ConsumerWidget {
  const PanicOpenAppsPicker({super.key, required this.config});

  final PanicSwitchConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _AppPicker(
    picked: config.appsToOpen,
    onAdd: (app) => savePanicSwitch(
      context,
      ref,
      (c) => c.appsToOpen.any((a) => a.id == app.id)
          ? c
          : c.copyWith(appsToOpen: [...c.appsToOpen, app]),
    ),
    onRemove: (app) => savePanicSwitch(
      context,
      ref,
      (c) => c.copyWith(
        appsToOpen: [
          for (final a in c.appsToOpen)
            if (a.id != app.id) a,
        ],
      ),
    ),
  );
}

/// The picked apps as chips over a searchable list of this computer's apps.
class _AppPicker extends ConsumerWidget {
  const _AppPicker({
    required this.picked,
    required this.onAdd,
    required this.onRemove,
  });

  final List<AppRef> picked;
  final void Function(AppRef app) onAdd;
  final void Function(AppRef app) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final apps = ref.watch(panicAppsProvider).asData?.value;
    final failed = apps?.isErr ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: s.md,
      children: [
        if (picked.isNotEmpty)
          Wrap(
            spacing: s.xs,
            runSpacing: s.xs,
            children: [
              for (final app in picked)
                EditorChip(
                  label: app.name,
                  icon: LucideIcons.appWindow300,
                  onRemove: () => onRemove(app),
                ),
            ],
          ),
        if (failed)
          Text(
            l.panicSwitchAppsFailed,
            style: context.typography.paragraph.copyWith(
              color: context.colors.textSecondary,
            ),
          )
        else
          SearchableDropdownField<AppRef>(
            items: apps?.valueOrNull ?? const [],
            value: null,
            labelOf: (a) => a.name,
            hintText: l.panicSwitchAddApp,
            searchHint: l.panicSwitchSearch,
            emptyLabel: l.panicSwitchNoMatches,
            onChanged: onAdd,
          ),
      ],
    );
  }
}
