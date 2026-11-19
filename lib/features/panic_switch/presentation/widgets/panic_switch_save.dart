import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/panic_switch_config.dart';
import '../providers/panic_switch_config_controller.dart';

/// Saves a change made in Settings, saying so when it could not be kept.
Future<void> savePanicSwitch(
  BuildContext context,
  WidgetRef ref,
  PanicSwitchConfig Function(PanicSwitchConfig config) change,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = AppL10n.of(context).panicSwitchSaveFailed;
  final saved = await ref.read(panicSwitchConfigProvider.notifier).edit(change);
  if (saved.isErr) showAppSnackOn(messenger, message, isError: true);
}
