import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';

/// Leads a detail header with "back to the previous ticket", shown only once
/// a ticket was opened from inside the panel (a parent / subtask or a linked
/// ticket).
class DetailBackButton extends ConsumerWidget {
  const DetailBackButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(ticketCanGoBackProvider)) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsetsDirectional.only(end: context.spacing.md),
      child: AppIconButton(
        icon: LucideIcons.arrowLeft300,
        tooltip: AppL10n.of(context).back,
        onPressed: () => ref.read(appNavProvider.notifier).back(),
      ),
    );
  }
}
