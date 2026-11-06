import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/cookie_source.dart';
import '../../domain/value_objects/cookie_browser.dart';
import '../util/cookie_browser_name.dart';

/// Why [source]'s cookies could not be read or imported, in the user's words.
String cookieFailureMessage(AppL10n l, CookieSource source, Failure failure) =>
    switch (failure) {
      AuthFailure() when source.browser == CookieBrowser.safari =>
        l.miniAppCookiesSafariAccess,
      AuthFailure() => l.miniAppCookiesKeychainDenied(
        cookieBrowserName(source.browser),
      ),
      NotFoundFailure() => l.miniAppCookiesNone,
      _ => l.miniAppCookiesFailed,
    };

/// Whether the way past [failure] is the Privacy settings (Safari's Full Disk
/// Access).
bool needsFullDiskAccess(CookieSource source, Failure failure) =>
    failure is AuthFailure && source.browser == CookieBrowser.safari;

/// Opens macOS's Full Disk Access list, where WorkNexus is switched on.
Future<void> openFullDiskAccessSettings() async {
  if (!Platform.isMacOS) return;
  await Process.run('open', [
    'x-apple.systempreferences:com.apple.preference.security'
        '?Privacy_AllFiles',
  ]);
}

/// Tells the user how an import of [source] went.
Future<void> reportCookieImport(
  BuildContext context,
  CookieSource source,
  Future<Result<int>> job,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l = AppL10n.of(context);
  final result = await job;
  if (messenger == null) return;
  switch (result) {
    case Ok(:final value):
      showAppSnackOn(messenger, l.miniAppCookiesImported(value));
    case Err(:final failure):
      showAppSnackOn(
        messenger,
        cookieFailureMessage(l, source, failure),
        isError: true,
      );
  }
}
