import 'package:flutter/foundation.dart';

import '../../domain/entities/cookie_source.dart';
import '../../domain/value_objects/cookie_browser.dart';

/// Whether [source]'s cookies can be imported here. Chrome on Windows
/// encrypts them so that only Chrome itself can read them (app-bound
/// encryption, Chrome 127+), so it is listed but cannot be picked.
bool cookieImportSupported(CookieSource source) =>
    !(defaultTargetPlatform == TargetPlatform.windows &&
        source.browser == CookieBrowser.chrome);
