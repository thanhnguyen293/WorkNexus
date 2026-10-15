import 'package:freezed_annotation/freezed_annotation.dart';

part 'mini_app_permission.freezed.dart';

/// What a page may ask to use. Kept apart from any web view's own list so the
/// choices stay stable when the web view changes.
enum MiniAppPermissionKind {
  notifications,
  clipboard,
  autoplay,
  multipleDownloads,
  localFonts,
  camera,
  microphone,
  location,
  other,
}

/// The user's answer to a request.
enum MiniAppPermissionDecision { allow, block }

/// A remembered answer: app [miniAppId] may ([allow]) or may not ([block]) use
/// [kind]. Without one for a kind, the user is asked.
@freezed
abstract class MiniAppPermissionGrant with _$MiniAppPermissionGrant {
  const factory MiniAppPermissionGrant({
    required String miniAppId,
    required MiniAppPermissionKind kind,
    required MiniAppPermissionDecision decision,
  }) = _MiniAppPermissionGrant;
}
