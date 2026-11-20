import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/app_ref.dart';
import '../../domain/entities/panic_switch_config.dart';
import '../providers/panic_switch_providers.dart';
import 'panic_check_row.dart';
import 'panic_switch_save.dart';

/// This computer's apps, each ticked when it is opened as the switch goes
/// off — tick as many as you like. Ticked ones come first; a search narrows
/// the rest.
class PanicAppChecklist extends ConsumerStatefulWidget {
  const PanicAppChecklist({super.key, required this.config});

  final PanicSwitchConfig config;

  @override
  ConsumerState<PanicAppChecklist> createState() => _PanicAppChecklistState();
}

class _PanicAppChecklistState extends ConsumerState<PanicAppChecklist> {
  /// Room for about eight apps before the list scrolls.
  static const _maxHeight = 280.0;

  final _search = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(AppRef app) => savePanicSwitch(
    context,
    ref,
    (c) => c.appsToOpen.any((a) => a.id == app.id)
        ? c.copyWith(
            appsToOpen: [
              for (final a in c.appsToOpen)
                if (a.id != app.id) a,
            ],
          )
        : c.copyWith(appsToOpen: [...c.appsToOpen, app]),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final picked = widget.config.appsToOpen;
    final pickedIds = {for (final a in picked) a.id};
    final loaded = ref.watch(panicAppsProvider);
    final result = loaded.asData?.value;
    // A Failure, or the lookup itself threw: either way say so, rather than
    // an empty "No matches" list.
    if (loaded.hasError || (result != null && result.isErr)) {
      return AppInlineNote(text: l.panicSwitchAppsFailed, isError: true);
    }
    final q = _query.trim().toLowerCase();
    bool matches(AppRef a) => q.isEmpty || a.name.toLowerCase().contains(q);
    final rest = [
      for (final a in result?.valueOrNull ?? const <AppRef>[])
        if (!pickedIds.contains(a.id) && matches(a)) a,
    ];
    final shown = [...picked.where(matches), ...rest];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: context.spacing.md,
      children: [
        AppSearchField(
          controller: _search,
          hint: l.panicSwitchSearchApps,
          onChanged: (v) => setState(() => _query = v),
        ),
        if (loaded.isLoading && result == null)
          const AppInlineSpinner()
        else if (shown.isEmpty)
          AppInlineNote(text: l.panicSwitchNoMatches)
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _maxHeight),
            // Built lazily: the icons are read only for the rows in view.
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: shown.length,
              itemBuilder: (context, i) => PanicCheckRow(
                label: shown[i].name,
                leading: _AppIcon(shown[i]),
                picked: pickedIds.contains(shown[i].id),
                onToggle: () => _toggle(shown[i]),
              ),
            ),
          ),
      ],
    );
  }
}

/// An app's own icon, or a generic window while it loads or when it has none.
class _AppIcon extends ConsumerWidget {
  const _AppIcon(this.app);

  final AppRef app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final side = context.sizes.iconLg;
    final bytes = ref.watch(panicAppIconProvider(app)).asData?.value;
    if (bytes == null) {
      return Icon(
        LucideIcons.appWindow300,
        size: side,
        color: context.colors.textTertiary,
      );
    }
    return Image.memory(
      bytes,
      width: side,
      height: side,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) => Icon(
        LucideIcons.appWindow300,
        size: side,
        color: context.colors.textTertiary,
      ),
    );
  }
}
