import '../../../../core/error/result.dart';
import '../entities/mini_app.dart';
import '../repositories/mini_app_repository.dart';

/// Gives [app] the icon of its site. Resolves to the app as kept; unchanged
/// when the site has no icon.
class RefreshMiniAppIcon {
  const RefreshMiniAppIcon(this._repository);

  final MiniAppRepository _repository;

  Future<Result<MiniApp>> call(MiniApp app) async {
    final fetched = await _repository.fetchSiteIcon(
      id: app.id,
      pageUrl: app.url,
    );
    switch (fetched) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final path):
        if (path == null) return Ok(app);
        final updated = app.copyWith(iconPath: path);
        final saved = await _repository.save(updated);
        return saved.fold((_) => Ok(updated), Err.new);
    }
  }
}
