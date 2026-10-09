import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/platform/desktop_notifier.dart';
import '../../../../core/platform/desktop_window_service.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_rail_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/app_release.dart';
import '../providers/update_controller.dart';
import '../providers/update_state.dart';
import 'update_dialog.dart';

/// Rail button (above Integrations) that appears once an update is
/// downloaded. Announces it once with an OS notification, whose click opens
/// the same dialog.
class UpdateRailButton extends ConsumerStatefulWidget {
  const UpdateRailButton({super.key});

  @override
  ConsumerState<UpdateRailButton> createState() => _UpdateRailButtonState();
}

class _UpdateRailButtonState extends ConsumerState<UpdateRailButton> {
  static const _payload = 'app_update';
  // Clear of the chat notifications, whose ids are 31-bit hashes.
  static const _notificationId = 0x7ffffff0;

  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    _taps = getIt<DesktopNotifier>().taps
        .where((payload) => payload == _payload)
        .listen((_) => _onNotificationTap());
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  Future<void> _onNotificationTap() async {
    await const DesktopWindowService().bringToFront();
    if (mounted) await _openDialog();
  }

  Future<void> _openDialog() =>
      showDialog<void>(context: context, builder: (_) => const UpdateDialog());

  void _announce(AppRelease release) {
    final l = AppL10n.of(context);
    unawaited(
      getIt<DesktopNotifier>().show(
        id: _notificationId,
        title: l.updateNotificationTitle('${release.version}'),
        body: l.updateNotificationBody,
        payload: _payload,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(updateControllerProvider, (previous, next) {
      if (next case UpdateReady(:final release) when previous is! UpdateReady) {
        _announce(release);
      }
    });
    final release = switch (ref.watch(updateControllerProvider)) {
      UpdateReady(:final release) => release,
      UpdateInstallFailed(:final release) => release,
      _ => null,
    };
    if (release == null) return const SizedBox.shrink();
    final c = context.colors;
    final dot = context.spacing.md;
    return AppRailButton(
      icon: PhosphorIconsLight.arrowCircleUp,
      selectedIcon: PhosphorIconsLight.arrowCircleUp,
      label: AppL10n.of(context).updateRailTooltip('${release.version}'),
      selected: false,
      onTap: _openDialog,
      badge: Container(
        width: dot,
        height: dot,
        decoration: BoxDecoration(
          color: c.accent,
          shape: BoxShape.circle,
          border: Border.all(
            color: c.surface,
            width: context.borders.hairline * 2,
          ),
        ),
      ),
    );
  }
}
