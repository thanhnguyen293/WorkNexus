import 'package:freezed_annotation/freezed_annotation.dart';

part 'dev_link.freezed.dart';

/// A code artifact linked to a ticket.
enum DevLinkKind { repo, branch, commit, pullRequest }

@freezed
abstract class DevLink with _$DevLink {
  const factory DevLink({
    required String id,
    required String ticketId,
    required DevLinkKind kind,
    required String label,
    String? url,
    String? externalRef,
  }) = _DevLink;
}
