import 'package:freezed_annotation/freezed_annotation.dart';

part 'mini_app_browser_state.freezed.dart';

/// What the toolbar and page cover show about one mini app's page.
@freezed
abstract class MiniAppBrowserState with _$MiniAppBrowserState {
  const MiniAppBrowserState._();

  const factory MiniAppBrowserState({
    /// Loading progress, 0 to 1; 1 when idle.
    @Default(1.0) double progress,
    @Default(false) bool canGoBack,
    @Default(false) bool canGoForward,

    /// Why the page could not load; null while it is fine.
    String? loadError,

    /// The page's current address.
    @Default('') String address,
  }) = _MiniAppBrowserState;

  bool get loading => progress < 1;
}
