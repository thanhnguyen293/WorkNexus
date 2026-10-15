import 'dart:async';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/mini_app.dart';
import '../repositories/mini_app_repository.dart';
import 'normalize_mini_app_url.dart';
import 'refresh_mini_app_icon.dart';

/// Applies an edit to [app]: a new address, name and icon. A blank [name]
/// becomes the site's host; an app left without an icon gets its site's.
class UpdateMiniApp {
  UpdateMiniApp(this._repository)
    : _refreshIcon = RefreshMiniAppIcon(_repository);

  final MiniAppRepository _repository;
  final RefreshMiniAppIcon _refreshIcon;
  static const _normalize = NormalizeMiniAppUrl();

  Future<Result<MiniApp>> call({
    required MiniApp app,
    required String url,
    required String name,
    required String? iconPath,
  }) async {
    final uri = _normalize(url);
    if (uri == null) return const Err(ParseFailure('Not a web address'));
    final updated = MiniApp(
      id: app.id,
      name: name.trim().isEmpty ? _normalize.defaultName(uri) : name.trim(),
      url: uri.toString(),
      iconPath: iconPath,
      // A new address starts from its own page.
      lastUrl: uri.toString() == app.url ? app.lastUrl : null,
      position: app.position,
    );
    final saved = await _repository.save(updated);
    if (saved is Err<void>) return Err(saved.failure);
    if (iconPath == null) unawaited(_refreshIcon(updated));
    return Ok(updated);
  }
}
