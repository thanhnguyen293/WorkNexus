import '../../../../core/error/result.dart';
import '../entities/link_preview.dart';
import '../repositories/link_preview_repository.dart';

/// The preview card for a link in a message.
class LoadLinkPreview {
  const LoadLinkPreview(this._repository);

  final LinkPreviewRepository _repository;

  Future<Result<LinkPreview?>> call(String url) => _repository.preview(url);
}
