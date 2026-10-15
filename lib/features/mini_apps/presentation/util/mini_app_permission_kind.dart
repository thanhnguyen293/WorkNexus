import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/mini_app_permission.dart';

/// How each kind of permission is shown, and how the web view's own names for
/// them map onto the app's.
extension MiniAppPermissionKindView on MiniAppPermissionKind {
  IconData get icon => switch (this) {
    MiniAppPermissionKind.notifications => LucideIcons.bell300,
    MiniAppPermissionKind.clipboard => LucideIcons.clipboard300,
    MiniAppPermissionKind.autoplay => LucideIcons.circlePlay300,
    MiniAppPermissionKind.multipleDownloads => LucideIcons.download300,
    MiniAppPermissionKind.localFonts => LucideIcons.type300,
    MiniAppPermissionKind.camera => LucideIcons.camera300,
    MiniAppPermissionKind.microphone => LucideIcons.mic300,
    MiniAppPermissionKind.location => LucideIcons.mapPin300,
    MiniAppPermissionKind.other => LucideIcons.shield300,
  };

  /// The name in the permissions list ("Camera").
  String label(AppL10n l) => switch (this) {
    MiniAppPermissionKind.notifications => l.miniAppPermNotificationsLabel,
    MiniAppPermissionKind.clipboard => l.miniAppPermClipboardLabel,
    MiniAppPermissionKind.autoplay => l.miniAppPermAutoplayLabel,
    MiniAppPermissionKind.multipleDownloads =>
      l.miniAppPermMultipleDownloadsLabel,
    MiniAppPermissionKind.localFonts => l.miniAppPermLocalFontsLabel,
    MiniAppPermissionKind.camera => l.miniAppPermCameraLabel,
    MiniAppPermissionKind.microphone => l.miniAppPermMicrophoneLabel,
    MiniAppPermissionKind.location => l.miniAppPermLocationLabel,
    MiniAppPermissionKind.other => l.miniAppPermOtherLabel,
  };

  /// What the page wants, as a phrase after "wants to" ("use your camera").
  String action(AppL10n l) => switch (this) {
    MiniAppPermissionKind.notifications => l.miniAppPermNotificationsAction,
    MiniAppPermissionKind.clipboard => l.miniAppPermClipboardAction,
    MiniAppPermissionKind.autoplay => l.miniAppPermAutoplayAction,
    MiniAppPermissionKind.multipleDownloads =>
      l.miniAppPermMultipleDownloadsAction,
    MiniAppPermissionKind.localFonts => l.miniAppPermLocalFontsAction,
    MiniAppPermissionKind.camera => l.miniAppPermCameraAction,
    MiniAppPermissionKind.microphone => l.miniAppPermMicrophoneAction,
    MiniAppPermissionKind.location => l.miniAppPermLocationAction,
    MiniAppPermissionKind.other => l.miniAppPermOtherAction,
  };

  /// One line on what allowing it means.
  String description(AppL10n l) => switch (this) {
    MiniAppPermissionKind.notifications => l.miniAppPermNotificationsDesc,
    MiniAppPermissionKind.clipboard => l.miniAppPermClipboardDesc,
    MiniAppPermissionKind.autoplay => l.miniAppPermAutoplayDesc,
    MiniAppPermissionKind.multipleDownloads =>
      l.miniAppPermMultipleDownloadsDesc,
    MiniAppPermissionKind.localFonts => l.miniAppPermLocalFontsDesc,
    MiniAppPermissionKind.camera => l.miniAppPermCameraDesc,
    MiniAppPermissionKind.microphone => l.miniAppPermMicrophoneDesc,
    MiniAppPermissionKind.location => l.miniAppPermLocationDesc,
    MiniAppPermissionKind.other => l.miniAppPermOtherDesc,
  };
}

/// What each of the web view's permission resources stands for (camera and
/// microphone together are two). A table, so a new one is a new line.
final _kindsByResource = <PermissionResourceType, List<MiniAppPermissionKind>>{
  PermissionResourceType.NOTIFICATIONS: [MiniAppPermissionKind.notifications],
  PermissionResourceType.CLIPBOARD_READ: [MiniAppPermissionKind.clipboard],
  PermissionResourceType.AUTOPLAY: [MiniAppPermissionKind.autoplay],
  PermissionResourceType.MULTIPLE_AUTOMATIC_DOWNLOADS: [
    MiniAppPermissionKind.multipleDownloads,
  ],
  PermissionResourceType.LOCAL_FONTS: [MiniAppPermissionKind.localFonts],
  PermissionResourceType.CAMERA: [MiniAppPermissionKind.camera],
  PermissionResourceType.MICROPHONE: [MiniAppPermissionKind.microphone],
  PermissionResourceType.CAMERA_AND_MICROPHONE: [
    MiniAppPermissionKind.camera,
    MiniAppPermissionKind.microphone,
  ],
  PermissionResourceType.GEOLOCATION: [MiniAppPermissionKind.location],
};

/// The kinds [resource] stands for; [MiniAppPermissionKind.other] for one the
/// app has no name for.
List<MiniAppPermissionKind> miniAppPermissionKindsOf(
  PermissionResourceType resource,
) => _kindsByResource[resource] ?? const [MiniAppPermissionKind.other];
