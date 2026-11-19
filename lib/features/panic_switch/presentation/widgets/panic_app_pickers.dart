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

/// The app brought forward: picked from the apps on this computer, removable.
class PanicTargetAppPicker extends StatelessWidget {
  const PanicTargetAppPicker({super.key, required this.config});

  final PanicSwitchConfig config;

  @override
  Widget build(BuildContext context) {
    final target = config.targetApp;
    return _AppPicker(
      picked: [?target],
      hintKey: _Hint.pick,
      onAdd: (ref, app) =>
          savePanicSwitch(context, ref, (c) => c.copyWith(targetApp: app)),
      onRemove: (ref, _) =>
          savePanicSwitch(context, ref, (c) => c.copyWith(targetApp: null)),
    );
  }
}

/// The apps hidden alongside: any number, each removable.
class PanicHiddenAppsPicker extends StatelessWidget {
  const PanicHiddenAppsPicker({super.key, required this.config});

  final PanicSwitchConfig config;

  @override
  Widget build(BuildContext context) => _AppPicker(
    picked: config.appsToHide,
    hintKey: _Hint.add,
    onAdd: (ref, app) => savePanicSwitch(
      context,
      ref,
      (c) => c.appsToHide.any((a) => a.id == app.id)
          ? c
          : c.copyWith(appsToHide: [...c.appsToHide, app]),
    ),
    onRemove: (ref, app) => savePanicSwitch(
      context,
      ref,
      (c) => c.copyWith(
        appsToHide: [
          for (final a in c.appsToHide)
            if (a.id != app.id) a,
        ],
      ),
    ),
  );
}

enum _Hint { pick, add }

/// The picked apps as chips over a searchable list of this computer's apps.
class _AppPicker extends ConsumerWidget {
  const _AppPicker({
    required this.picked,
    required this.hintKey,
    required this.onAdd,
    required this.onRemove,
  });

  final List<AppRef> picked;
  final _Hint hintKey;
  final void Function(WidgetRef ref, AppRef app) onAdd;
  final void Function(WidgetRef ref, AppRef app) onRemove;

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
                  onRemove: () => onRemove(ref, app),
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
            hintText: switch (hintKey) {
              _Hint.pick => l.panicSwitchPickApp,
              _Hint.add => l.panicSwitchAddApp,
            },
            searchHint: l.panicSwitchSearch,
            emptyLabel: l.panicSwitchNoMatches,
            onChanged: (app) => onAdd(ref, app),
          ),
      ],
    );
  }
}
