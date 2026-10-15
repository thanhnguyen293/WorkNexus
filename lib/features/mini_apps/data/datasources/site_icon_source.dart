import 'dart:typed_data';

/// A site's icon image and the file extension to keep it under.
typedef SiteIcon = ({Uint8List bytes, String extension});

/// Where an app's icon comes from when the user did not pick one: the site
/// itself. The repository depends on this, not on how it is fetched.
abstract interface class SiteIconSource {
  /// The icon of the page at [page]; null when the site offers none.
  Future<SiteIcon?> fetch(Uri page);
}
