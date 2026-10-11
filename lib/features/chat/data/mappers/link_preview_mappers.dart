import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../domain/entities/link_preview.dart';

/// A fetched preview as a row; null [preview] stores "nothing to show".
ChatLinkPreviewsCompanion linkPreviewToRow(
  String url,
  LinkPreview? preview, {
  required DateTime fetchedAt,
}) => ChatLinkPreviewsCompanion(
  url: Value(url),
  empty: Value(preview == null),
  pageUrl: Value(preview?.url),
  siteName: Value(preview?.siteName),
  title: Value(preview?.title),
  description: Value(preview?.description),
  imageUrl: Value(preview?.imageUrl),
  fetchedAt: Value(fetchedAt),
);

/// The stored preview; null when the page had nothing to show.
LinkPreview? linkPreviewFromRow(ChatLinkPreviewRow row) => row.empty
    ? null
    : LinkPreview(
        url: row.pageUrl ?? row.url,
        siteName: row.siteName,
        title: row.title,
        description: row.description,
        imageUrl: row.imageUrl,
      );
