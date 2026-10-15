import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/mini_app.dart';
import '../repositories/mini_app_repository.dart';
import 'normalize_mini_app_url.dart';
import 'refresh_mini_app_icon.dart';

/// Adds the web page at [url] to the end of the rail. A blank [name] becomes
/// the site's host. The site's icon is fetched afterwards, without making the
/// caller wait for it: it shows up when it arrives.
class AddMiniApp {
  AddMiniApp(this._repository) : _refreshIcon = RefreshMiniAppIcon(_repository);

  final MiniAppRepository _repository;
  final RefreshMiniAppIcon _refreshIcon;
  static const _normalize = NormalizeMiniAppUrl();

  Future<Result<MiniApp>> call({
    required String url,
    String name = '',
    required List<MiniApp> existing,
  }) async {
    final uri = _normalize(url);
    if (uri == null) return const Err(ParseFailure('Not a web address'));
    final next = existing.isEmpty
        ? 0
        : existing.map((a) => a.position).reduce((a, b) => a > b ? a : b) + 1;
    final app = MiniApp(
      id: const Uuid().v4(),
      name: name.trim().isEmpty ? _normalize.defaultName(uri) : name.trim(),
      url: uri.toString(),
      position: next,
    );
    final saved = await _repository.save(app);
    if (saved is Err<void>) return Err(saved.failure);
    unawaited(_refreshIcon(app));
    return Ok(app);
  }
}
