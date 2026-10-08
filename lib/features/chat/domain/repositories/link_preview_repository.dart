import '../../../../core/error/result.dart';
import '../entities/link_preview.dart';

/// Fetches previews of web pages linked in chat. `Ok(null)` means the page
/// has nothing worth showing.
abstract class LinkPreviewRepository {
  Future<Result<LinkPreview?>> preview(String url);
}
