/// Whether [page] is on the mini app's own site ([appUrl]'s scheme, host and
/// port). A page the app moved to on another site (a sign-in, an outside
/// link) does not get what the user allowed the app.
class IsMiniAppOrigin {
  const IsMiniAppOrigin();

  bool call(String appUrl, Uri? page) {
    final app = Uri.tryParse(appUrl);
    if (app == null || page == null || app.host.isEmpty) return false;
    return app.scheme.toLowerCase() == page.scheme.toLowerCase() &&
        app.host.toLowerCase() == page.host.toLowerCase() &&
        app.port == page.port;
  }
}
