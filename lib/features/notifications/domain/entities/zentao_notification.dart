import 'package:freezed_annotation/freezed_annotation.dart';

part 'zentao_notification.freezed.dart';

/// One ZenTao web notification (the bell menu), e.g. "JunNg assigned Bug
/// [#6492::Feed: video autoplay is delayed]".
@freezed
abstract class ZenTaoNotification with _$ZenTaoNotification {
  const factory ZenTaoNotification({
    required String accountId,
    required String id,

    /// What happened, without the object link: "JunNg assigned Bug".
    required String summary,

    /// The linked object's ZenTao type (`bug`, `task`, `story`…), lower-case.
    String? objectType,
    String? objectId,
    String? objectTitle,

    /// The object's page on the ZenTao server.
    String? url,
    @Default(false) bool read,
    DateTime? createdAt,
  }) = _ZenTaoNotification;
}
