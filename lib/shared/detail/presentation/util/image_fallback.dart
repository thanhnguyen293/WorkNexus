import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../core/util/image_urls.dart';
import '../../../../core/widgets/markdown_text.dart';

/// The inline-image "open in browser" fallback for a ticket's [MarkdownText]:
/// a resolver that turns a raw inline-image URL into a browser-openable link,
/// plus an opener that launches it.
///
/// It exists because some provider assets can't be fetched in-app — most
/// notably **GitLab < 17.4** uploads (`/uploads/…`), which only a browser
/// session cookie can read (a PAT is rejected and the API endpoint doesn't
/// exist yet). When the in-app fetch fails, [MarkdownText] shows a "copy link /
/// open in browser" bar built from these two callbacks instead of a
/// broken-image icon. Other providers get the same affordance for consistency.
class ImageFallback {
  const ImageFallback._(this.resolveUrl, this.open);

  /// Builds the fallback for [ticket]'s images. [account] supplies the instance
  /// base URL; a GitLab ticket additionally scopes uploads by its project path.
  factory ImageFallback.forTicket(Ticket ticket, Account? account) {
    final projectPath = switch (ticket.providerEntity) {
      final GitLabItemEntity e => e.projectPath,
      _ => null,
    };
    return ImageFallback._(
      (url) => providerImageWebUrl(
        providerType: ticket.providerType,
        baseUrl: account?.baseUrl,
        projectPath: projectPath,
        rawUrl: url,
      ),
      openExternally,
    );
  }

  /// Resolves a raw inline-image URL to a browser-openable link, or null when
  /// it can't be built (see [providerImageWebUrl]).
  final ImageUrlResolver resolveUrl;

  /// Opens an already-resolved link externally (see [openExternally]) — wired to
  /// [MarkdownText.onOpenImage] so the fallback bar can launch the browser.
  final ImageExternalOpener open;
}
