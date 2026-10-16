import '../../../../core/navigation/mini_app_links.dart';
import '../../../../core/platform/link_router.dart';

/// Takes a link the page of mini app [currentAppId] opens in a window of its
/// own, the way a link tapped elsewhere in the app goes: to the app if it
/// shows that link itself, else to the mini app of that site. Never to
/// [currentAppId] itself — its own links stay in its window. False when
/// nothing took it, so the window opens as a pop-up.
bool routeMiniAppWindowLink(
  LinkRouter router,
  List<MiniAppLinkTarget> targets,
  String url, {
  required String currentAppId,
}) => router.route(
  url,
  skip: findMiniAppForLink(targets, url) == currentAppId
      ? const {LinkStage.miniApp}
      : const {},
);
