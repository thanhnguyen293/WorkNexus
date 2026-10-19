import '../../../../core/navigation/mini_app_links.dart';
import '../../../../core/platform/link_router.dart';
import '../../domain/usecases/is_sign_in_window.dart';

/// Takes a link the page of mini app [currentAppId] opens in a window of its
/// own, the way a link tapped elsewhere in the app goes: to the app if it
/// shows that link itself, else to the mini app of that site. Never to
/// [currentAppId] itself — its own links stay in its window. False when
/// nothing took it, so the window opens as a pop-up.
///
/// Never a sign-in ([IsSignInWindow]): the page waits on that window for an
/// answer and cannot get it if the window is carried off to another mini app,
/// so it always stays a pop-up. [windowWidth] and [windowHeight] are the size
/// the page asked the window to have, if it did.
bool routeMiniAppWindowLink(
  LinkRouter router,
  List<MiniAppLinkTarget> targets,
  String url, {
  required String currentAppId,
  double? windowWidth,
  double? windowHeight,
}) {
  final signIn = const IsSignInWindow()(
    OpenedWindow(url: url, width: windowWidth, height: windowHeight),
  );
  if (signIn) return false;
  return router.route(
    url,
    skip: findMiniAppForLink(targets, url) == currentAppId
        ? const {LinkStage.miniApp}
        : const {},
  );
}
