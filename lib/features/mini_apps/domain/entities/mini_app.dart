import 'package:freezed_annotation/freezed_annotation.dart';

part 'mini_app.freezed.dart';

/// A web page the user added to the rail, opened inside the app.
@freezed
abstract class MiniApp with _$MiniApp {
  const factory MiniApp({
    required String id,
    required String name,

    /// Absolute `http` / `https` address, as normalised by
    /// [NormalizeMiniAppUrl].
    required String url,

    /// The icon's image file on this device; null shows the name's initial.
    String? iconPath,

    /// The page the app was last on, reopened next time; null opens [url].
    String? lastUrl,

    /// Order on the rail, first to last.
    required int position,
  }) = _MiniApp;
}
